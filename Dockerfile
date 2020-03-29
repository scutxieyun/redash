FROM node:10 as frontend-builder

WORKDIR /frontend
COPY package.json package-lock.json /frontend/
RUN npm install

COPY client /frontend/client
COPY webpack.config.js /frontend/
RUN npm run build

FROM redash/base:debian

# Controls whether to install extra dependencies needed for all data sources.
ARG skip_ds_deps

RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-sqlplus-linux.x64-19.6.0.0.0dbru.zip
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip

RUN apt-get update  -y
RUN apt-get install -y unzip

RUN unzip instantclient-sqlplus-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/
RUN unzip instantclient-basic-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/
RUN unzip instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip -d /usr/local/

RUN apt-get install libaio-dev -y
RUN apt-get clean -y

RUN ln -s /usr/local/instantclient_19_6 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus

ENV ORACLE_HOME=/usr/local/instantclient
# We first copy only the requirements file, to avoid rebuilding on every file
# change.
COPY requirements.txt requirements_bundles.txt requirements_dev.txt requirements_oracle_ds.txt requirements_all_ds.txt ./
RUN pip install -r requirements.txt -r requirements_dev.txt -r requirements_oracle_ds.txt
RUN if [ "x$skip_ds_deps" = "x" ] ; then pip install -r requirements_all_ds.txt ; else echo "Skipping pip install -r requirements_all_ds.txt" ; fi

COPY . /app
COPY --from=frontend-builder /frontend/client/dist /app/client/dist
RUN chown -R redash /app
USER redash

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["server"]
