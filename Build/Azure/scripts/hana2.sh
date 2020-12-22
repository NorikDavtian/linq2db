#!/bin/bash

docker run -d --name hana2 -p 39013:39013 store/saplabs/hanaexpress:2.00.045.00.20200121.1 --agree-to-sap-license --passwords-url file:///hana/password.json

#echo Generate password file
cat <<-EOJSON > hana_password.json
{"master_password": "Passw0rd"}
EOJSON

docker cp hana_password.json hana2:/hana/password.json
docker exec hana2 sudo chmod 600 /hana/password.json
docker exec hana2 sudo chown 12000:79 /hana/password.json

docker ps -a

git clone https://github.com/MaceWindu/linq2db.ci.git ~/linq2db_ci

retries=0
until docker logs hana2 | grep -q 'Startup finished'; do
    sleep 5
    retries=`expr $retries + 1`
    echo waiting for hana2 to start
    if [ $retries -gt 100 ]; then
        echo hana2 not started or takes too long to start
        exit 1
    fi;
done

docker logs hana2

~/linq2db_ci/providers/saphana/linux/HDBSQL/hdbsql -d HXE -n localhost:39013 -u SYSTEM -p Passw0rd CREATE SCHEMA TESTDB
~/linq2db_ci/providers/saphana/linux/HDBSQL/hdbsql -d HXE -n localhost:39013 -u SYSTEM -p Passw0rd ALTER USER SYSTEM CLEAR PARAMETER STATEMENT MEMORY LIMIT

cat <<-EOJSON > UserDataProviders.json
{
    "BASE.Azure": {
        "BasedOn": "AzureConnectionStrings",
        "DefaultConfiguration": "SQLite.MS",
        "TraceLevel": "Info",
        "Connections": {
            "SapHana.Odbc": {
                "ConnectionString": "Driver=$HOME/linq2db_ci/providers/saphana/linux/ODBC/libodbcHDB.so;SERVERNODE=localhost:39013;databaseName=HXE;CS=TESTDB;UID=SYSTEM;PWD=Passw0rd;"
            }
        }
    },
    "CORE21.Azure": {
        "BasedOn": "BASE.Azure",
        "Providers": [
            "SapHana.Odbc"
        ]
    },
    "CORE31.Azure": {
        "BasedOn": "BASE.Azure",
        "Providers": [
            "SapHana.Odbc"
        ]
    },
    "NET50.Azure": {
        "BasedOn": "BASE.Azure",
        "Providers": [
            "SapHana.Odbc"
        ]
    }
}
EOJSON
