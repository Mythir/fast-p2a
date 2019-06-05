export MAVEN_OPTS="-Xmx4G"
mvn package -nsu
mvn exec:java -nsu