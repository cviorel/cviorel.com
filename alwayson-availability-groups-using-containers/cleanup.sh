#!/bin/bash

docker rm sql_node_01 sql_node_02 sql_node_03
docker image rm mssql2019-custom
docker volume rm linux_sqlbackup
docker volume rm linux_sqldata
docker volume rm linux_sqllog
docker volume rm linux_sqlsystem

docker volume rm linux_sqldata1
docker volume rm linux_sqllog1
docker volume rm linux_sqlsystem1

docker volume rm linux_sqldata2
docker volume rm linux_sqllog2
docker volume rm linux_sqlsystem2

docker volume rm linux_sqldata3
docker volume rm linux_sqllog3
docker volume rm linux_sqlsystem3
