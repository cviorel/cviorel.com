
# Overview

* Build a docker image based on Ubuntu 18.04 running SQL Server 2019
* Review the `ag.sql` with the T-SQL you want to run after SQL Server has started

# How to Run
## Clone this repo
```
git clone https://github.com/cviorel/cviorel.com.git
```
## Modify the dockerfile
Review the `linux\dockerfile` and make changes to fit your needs.
By default we're building a 3 nodes Availability Group.

## Modify the .sql files
Modify the `linux\ag.sql` file with the TSQL that you want to customize the SQL Server container with.

## Build the image 
Build with `docker build`:
```
cd cviorel.com/alwayson-availability-groups-using-containers
docker build -t mssql2019-custom -f linux/dockerfile .
```

## Run the container(s)
Spin up the 3 node AG:
```
docker-compose -f linux/docker-compose.yaml up -d
```

## Stop the container(s)
```
docker-compose -f linux/docker-compose.yaml down
```

Note: MSSQL passwords must be at least 8 characters long, contain upper case, lower case and digits.  

# See it in action
![](https://github.com/cviorel/cviorel.com/blob/main/alwayson-availability-groups-using-containers/alwayson-availability-groups-using-containers.gif)
