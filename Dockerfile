FROM docker.elastic.co/elasticsearch/elasticsearch:7.12.1 as package_builder

RUN dnf update -y && \
    dnf install -y make cmake unzip pkg-config gcc gcc-c++ wget nano git maven java-11-openjdk-devel.x86_64 java-11-openjdk.x86_64
ENV JAVA_HOME /etc/alternatives/java_sdk_11

WORKDIR /
COPY elasticsearch-analysis-vietnamese/pom.xml .
RUN mvn verify clean --fail-never

COPY elasticsearch-analysis-vietnamese /elasticsearch-analysis-vietnamese
COPY coccoc-tokenizer /coccoc-tokenizer

WORKDIR /elasticsearch-analysis-vietnamese
RUN mvn package -Dmaven.test.skip

RUN mkdir /coccoc-tokenizer/build
WORKDIR /coccoc-tokenizer/build
RUN cmake -DBUILD_JAVA=1 ..
RUN make install

FROM docker.elastic.co/elasticsearch/elasticsearch:7.12.1
WORKDIR /usr/share/tokenizer/dicts
COPY coccoc-tokenizer/dicts/tokenizer .
COPY coccoc-tokenizer/dicts/vn_lang_tool .
COPY --from=package_builder /coccoc-tokenizer/build/libcoccoc_tokenizer_jni.so /usr/lib
COPY --from=package_builder /coccoc-tokenizer/build/multiterm_trie.dump /usr/share/tokenizer/dicts
COPY --from=package_builder /coccoc-tokenizer/build/nontone_pair_freq_map.dump /usr/share/tokenizer/dicts
COPY --from=package_builder /coccoc-tokenizer/build/syllable_trie.dump /usr/share/tokenizer/dicts
COPY --from=package_builder /elasticsearch-analysis-vietnamese/target/releases/elasticsearch-analysis-vietnamese-7.12.1.zip /
RUN echo "Y" | /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///elasticsearch-analysis-vietnamese-7.12.1.zip && \
    /usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-icu
