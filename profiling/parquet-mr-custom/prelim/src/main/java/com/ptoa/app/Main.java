package com.ptoa.app;


import org.apache.avro.Schema;
import org.apache.avro.generic.GenericRecord;
import org.apache.hadoop.conf.Configuration;
import org.apache.parquet.avro.AvroParquetReader;
import org.apache.parquet.avro.AvroParquetWriter;
import org.apache.parquet.hadoop.ParquetReader;
import org.apache.hadoop.fs.Path;
import org.apache.parquet.hadoop.ParquetWriter;
import org.apache.parquet.column.ParquetProperties.WriterVersion;
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

    private CustomBuilder(Path file) {
      super(file);
    }

    @Override
    protected CustomBuilder self() {
      return this;
    }

    @Override
    protected WriteSupport<Group> getWriteSupport(Configuration conf) {
      return new GroupWriteSupport();
    }

  }

  public static void main(String[] args) throws IOException {
    Path file = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/gen-input/ref_int64array.parquet");
    Path destPath = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/gen-input/hw_int64array.parquet");

    ParquetFileReader reader = new ParquetFileReader(conf, file, ParquetMetadataConverter.NO_FILTER);
    ParquetMetadata readFooter = reader.getFooter();
    MessageType schema = readFooter.getFileMetaData().getSchema();
    ParquetFileReader r = new ParquetFileReader(conf, file, readFooter);
    reader.close();
    PageReadStore pages = null;

    GroupWriteSupport.setSchema(schema, conf);
    
    File t = new File(destPath.toString());
    t.delete();
    // This (deprecated) ParquetWriter constructor does not allow me to change the page row count limit, which is normally set on 20000.
    // In order to change this the source code will have to be changed or we need to extend the ParquetWriter builder.
    //CustomBuilder test = new CustomBuilder(destPath);
    //ParquetWriter<Group> writer = test.build();
    
    ParquetWriter<Group> writer = new ParquetWriter<Group>(
                destPath,
                new GroupWriteSupport(),
                CompressionCodecName.UNCOMPRESSED,
                10000000, //Row group size
                10000000, //Page size
                12315, //Dict page limit
                false, //Enable dictionary
                false, //Validation
                WriterVersion.PARQUET_2_0,
                conf);

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

    try{
      PrintFooter.main(new String[] {destPath.toString()});
    } catch (Exception e){
      e.printStackTrace();
    }
  }

}