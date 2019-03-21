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

import java.io.File;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/*
 * Code taken from http://isolineltd.com/blog/2018/10/17/Reading-and-Writing-Parquet-Files-in-Different-Languages as an example
 * for reading and writing Parquet files in Java. For now Java functionality is not needed in the ptoa tools so it is just left
 * here for future reference.
 */

public class Main {

   private static final Configuration conf = new Configuration();

   public static void main(String[] args) throws IOException {

      Path file = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/parquet-cpp/debug/int64array.prq");
      Path outUncompressed = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/parquet-mr-custom/java.uncompressed.parquet");
      Path outGzipped = new Path("/home/lars/Documents/GitHub/fast-p2a/profiling/parquet-mr-custom/java.snappy.parquet");

      List<GenericRecord> allRecords = new ArrayList<GenericRecord>();
      Schema schema = null;

      for(int i = 0; i < 11; i++) {

         //read
         ParquetReader<GenericRecord> reader = AvroParquetReader.<GenericRecord>builder(file).build();
         GenericRecord record;
         while((record = reader.read()) != null) {
            if(i == 0) {
               //add once
               allRecords.add(record);
               if(schema == null) {
                  schema = record.getSchema();
               }
            }
         }
         reader.close();

         writeTest(i, CompressionCodecName.UNCOMPRESSED, outUncompressed,
            schema, allRecords);

         writeTest(i, CompressionCodecName.SNAPPY, outGzipped,
            schema, allRecords);
      }
   }

   private static void writeTest(int iteration, CompressionCodecName codec,
                                 Path destPath, Schema schema, List<GenericRecord> records) throws IOException {
      File t = new File(destPath.toString());
      t.delete();
      ParquetWriter<GenericRecord> writer = AvroParquetWriter
         .<GenericRecord>builder(destPath)
         .withCompressionCodec(codec)
         .withSchema(schema)
         .withDictionaryEncoding(false)
         .withDictionaryPageSize(10000000)
         .withPageSize(1000)
         .withRowGroupSize(10000000)
         .withWriterVersion(WriterVersion.PARQUET_2_0)
         .build();
      for(GenericRecord wr: records) {
         writer.write(wr);
      }
      writer.close();
   }
}