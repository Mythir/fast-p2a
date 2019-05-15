package com.ptoa.app;


import org.apache.avro.Schema;
import org.apache.hadoop.conf.Configuration;
import org.apache.parquet.hadoop.ParquetReader;
import org.apache.hadoop.fs.Path;
import org.apache.parquet.hadoop.ParquetWriter;
import org.apache.parquet.column.ParquetProperties.WriterVersion;
import org.apache.parquet.column.ParquetProperties;
import org.apache.parquet.hadoop.metadata.CompressionCodecName;
import org.apache.parquet.example.data.Group;
import org.apache.parquet.example.data.simple.convert.GroupRecordConverter;
import org.apache.parquet.format.converter.ParquetMetadataConverter;
import org.apache.parquet.hadoop.ParquetFileReader;
import org.apache.parquet.hadoop.metadata.ParquetMetadata;
import org.apache.parquet.io.ColumnIOFactory;
import org.apache.parquet.io.MessageColumnIO;
import org.apache.parquet.io.RecordReader;
import org.apache.parquet.schema.MessageType;
import org.apache.parquet.schema.Type;
import org.apache.parquet.column.page.PageReadStore;
import org.apache.parquet.hadoop.api.WriteSupport;
import org.apache.parquet.hadoop.example.GroupWriteSupport;
import org.apache.parquet.hadoop.PrintFooter;
import org.apache.parquet.column.values.factory.ValuesWriterFactory;
import org.apache.parquet.hadoop.util.HadoopOutputFile;
import org.apache.parquet.hadoop.ParquetFileWriter;

import java.io.File;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.HashMap;
import java.util.Map;

public class Main {
  private static final Configuration conf = new Configuration();

  public static class CustomBuilder extends ParquetWriter.Builder<Group, CustomBuilder> {

    private MessageType schema = null;

    private CustomBuilder(Path file) {
      super(file);
    }

    @Override
    protected CustomBuilder self() {
      return this;
    }

    @Override
    protected WriteSupport<Group> getWriteSupport(Configuration conf) {
      GroupWriteSupport.setSchema(schema, conf);
      return new GroupWriteSupport();
    }

    public CustomBuilder withSchema(MessageType prq_schema, Configuration conf) {
      this.schema = prq_schema;
      return self();
    }

    public CustomBuilder withValuesWriterFactory(ValuesWriterFactory factory) {
      this.encodingPropsBuilder.withValuesWriterFactory(factory);
      return self();
    }

  }

  public static void main(String[] args) throws IOException {
    Path file = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/gen-input/ref_int32array.parquet");
    Path destPath = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/gen-input/hw_delta_varied_100ps_int32.parquet");

    ParquetFileReader reader = new ParquetFileReader(conf, file, ParquetMetadataConverter.NO_FILTER);
    ParquetMetadata readFooter = reader.getFooter();
    MessageType schema = readFooter.getFileMetaData().getSchema();
    ParquetFileReader r = new ParquetFileReader(conf, file, readFooter);
    reader.close();
    PageReadStore pages = null;
    
    ValuesWriterFactory customFactory = new CustomV2ValuesWriterFactory();

    File t = new File(destPath.toString());
    t.delete();

    //GroupWriteSupport.setSchema(schema, conf);
    //ParquetProperties.Builder encodingPropsBuilder = ParquetProperties.builder();
    //encodingPropsBuilder.withPageSize(10000000)
    //                    .withPageRowCountLimit(1000000000)
    //                    .withDictionaryEncoding(false)
    //                    .withValuesWriterFactory(customFactory)
    //                    .withWriterVersion(WriterVersion.PARQUET_2_0);
//
    //ParquetWriter<Group> writer = new ParquetWriter(
    //                                HadoopOutputFile.fromPath(destPath, conf),
    //                                ParquetFileWriter.Mode.OVERWRITE,
    //                                new GroupWriteSupport(),
    //                                CompressionCodecName.UNCOMPRESSED,
    //                                Integer.MAX_VALUE,
    //                                false,
    //                                conf,
    //                                ParquetWriter.MAX_PADDING_SIZE_DEFAULT,
    //                                encodingPropsBuilder.build());


    CustomBuilder writerBuilder = new CustomBuilder(destPath);
    writerBuilder.withSchema(schema, conf)
                 .withCompressionCodec(CompressionCodecName.UNCOMPRESSED)
                 .withRowGroupSize(Integer.MAX_VALUE)//
                 .withPageSize(100)
                 .withPageRowCountLimit(200)
                 .withDictionaryEncoding(false)
                 .withValidation(false)
                 //.withValuesWriterFactory(customFactory)
                 .withWriterVersion(WriterVersion.PARQUET_2_0);
    ParquetWriter<Group> writer = writerBuilder.build();

    try {
      while (null != (pages = r.readNextRowGroup())) {
        long rows = pages.getRowCount();
        System.out.println("Number of rows: " + pages.getRowCount());

        MessageColumnIO columnIO = new ColumnIOFactory().getColumnIO(schema);
        RecordReader<Group> recordReader = columnIO.getRecordReader(pages, new GroupRecordConverter(schema));
        for (int i = 0; i < rows; i++) {
          Group g = (Group) recordReader.read();
          writer.write(g);
        }
      }
    } finally {
      System.out.println("close the reader and writer");

      r.close();
      writer.close();
    }
    /*
    try{
      PrintFooter.main(new String[] {destPath.toString()});
    } catch (Exception e){
      e.printStackTrace();
    }
    */
  }

}