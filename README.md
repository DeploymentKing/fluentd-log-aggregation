# Fluentd Log Aggregation

This project allows for the quick deployment of a fully functioning EFK Stack.
- (E)lasticsearch
- (F)luentD
- (K)ibana

The intended use is as a local development environment to try out Fluentd configuration before deployment to an environment.
I have also included an optional NGINX web server that enables Basic authentication access control to kibana (if using
the XPack extension). In addition to this, there are a collection of "sources" that feed the EFK stack. For example the
folder `via-td-agent` contains Docker files that can launch and configure an Ubuntu box that will install the td-agent
and run a Java JAR from which we can control the type of logging to be sent to EFK

## Table of Contents

<!-- toc -->

- [Requirements](#requirements)
  * [Pre-requisites](#pre-requisites)
  * [Install supporting tools](#install-supporting-tools)
- [Quick & Easy Startup - OSS](#quick--easy-startup---oss)
- [Quick & Easy Startup - Default (with XPack Extensions)](#quick--easy-startup---default-with-xpack-extensions)
- [Log Sources](#log-sources)
  * [Logging via driver](#logging-via-driver)
    + [Launch Command](#launch-command)
  * [Logging via td-agent](#logging-via-td-agent)
    + [Launch Command](#launch-command-1)
    + [Changing the JAR log output type](#changing-the-jar-log-output-type)
    + [Changing the td-agent configuration](#changing-the-td-agent-configuration)
    + [Adding a new environment variable for use in the container](#adding-a-new-environment-variable-for-use-in-the-container)
- [Getting started with Kibana](#getting-started-with-kibana)
  * [Define index pattern](#define-index-pattern)
  * [View logs](#view-logs)
- [Docker Clean Up](#docker-clean-up)
- [References](#references)
- [Useful Articles](#useful-articles)

<!-- tocstop -->

## Requirements
All these instructions are for macOS only.

### Pre-requisites
Install
- [Homebrew](https://docs.brew.sh/Installation.html)
- [Homebrew Cask](https://caskroom.github.io/)

### Install supporting tools
```bash
brew cask install docker
```

## Quick & Easy Startup - OSS

Ensure the .env file has the setting `FLAVOUR_ELK` set to a value of `-oss`

```bash
docker-compose -p efk up
```

You will then be able to access the stack via the following:
- Elasticsearch @ [http://localhost:9200](http://localhost:9200)
- Kibana @ [http://localhost:5601](http://localhost:5601)

## Quick & Easy Startup - Default (with XPack Extensions)

Ensure the .env file has the setting `FLAVOUR_ELK` set to an empty string.

```bash
docker-compose -f docker-compose.yml -f nginx/docker-compose.yml -p efk up
```

You will then be able to access the stack via the following:
- Kibana @ [http://localhost:8080](http://localhost:8080)

When accessing via the NGINX container you do not need to supply the username and password credentials as it uses the 
`htpasswd.users` file which contains the default username and password of `elastic` and `changeme`. If you wish to use
different credentials then replace the text in the file using the following command 
`htpasswd -b ./nginx/config/htpasswd.users newuser newpassword`

:warning: You must use the `--build` flag on docker-compose when switching between `FLAVOUR_ELK` values e.g.
```bash
docker-compose -p efk up --build
```

## Log Sources

### Logging via driver
This is a simple log source that simply uses the log driver feature of Docker

```yaml
logging:
  driver: fluentd
  options:
    fluentd-address: localhost:24224
    tag: httpd.access
```

The docker image `httpd:alpine` is used to create a simple Apache web server. This will output the logs of the httpd 
process to STDOUT which gets picked up by the logging driver above.

#### Launch Command
```bash
docker-compose -f docker-compose.yml -f via-logging-driver/docker-compose.yml -p efk up
```

### Logging via td-agent
This source is based on an Ubuntu box with OpenJDK Java installed along with the td-agent. The executable is a JAR stored
in the executables folder that will log output controlled by log4j2 via slf4j. The JAR is controlled by the java-logger
project mentioned [here](#references). See the README of that project for further information.

#### Launch Command
```bash
docker-compose -f docker-compose.yml -f via-td-agent/docker-compose.yml -p efk up
```

#### Changing the JAR log output type
In order to change the kind of logging output from the JAR, e.g. from single line logs to multi-line logs, the environment
variable `LOGGER_ENTRY_POINT` needs to be set. This can be achieved via the .env file found in the root of the project.
Simply uncomment the desired class.

#### Changing the td-agent configuration
To try out different configuration options simply change the `FLUENTD_CONF` setting in the `via-td-agent/docker-compose.yml`
environment section to one of the files that are listed in `via-td-agent/config` and then rebuild the stack.

#### Adding a new environment variable for use in the container
In order to make a new environment variable available to the td-agent process in the container it is necessary to add
the variable to a number of files to make sure it gets propagated successfully. The files to update are:

| File | Description |
| --- | --- |
| .env | Contains a list of all the environment variables that can be passed to the container |
| via-td-agent/docker-compose.yml | This passes a sub-set of the environment variables to the docker container |
| via-td-agent/executables/entrypoint.sh | This takes a sub-set of the environment variables within the container ans makes them available to the td-agent service via /etc/default/td-agent |
| via-td-agent/config/td-agent-*.conf | The configuration files can make use of any variables defined in /etc/default/td-agent |

If you run the command below within this repo you will see an example of which files need to be changed and how.
```bash
git diff 66af1ad..857f181
```

## Getting started with Kibana
Once the stack has launched it should be possible to access kibana via [http://localhost:5601](http://localhost:5601).
It is not possible to instantly see the log output, first it is necessary to setup an index pattern. Kibana uses index
patterns to retrieve data from Elasticsearch indices for things like visualizations.

### Define index pattern
- Click this [link](http://localhost:5601/app/kibana#/management/kibana/index?_g=()) to navigate to the "Create index pattern" page
- Step 1 of 2: Define index pattern: type `fluentd*` into the "Index pattern" text box
- Click the "Next step" button
- Step 2 of 2: Configure settings: select `@timestamp` in the "Time Filter field name" drop-down list box
- Click the "Create index pattern" button

### View logs
- Click this [link](http://localhost:5601/app/kibana#/discover?_g=()) to navigate to the Discover page
- Click the "Auto-refresh" button at the top right of the page
- Select `5 seconds` from the drop-down panel that immediately appears
- Select the fields you wish to summarize in the table next to the left hand menu by hovering over the field name and
clicking the contextual "add" button. Select at least the "log" and "message" fields
- The selected fields should move from the "Available Fields" section to the "Selected Fields" section
- If using the logging driver you can trigger new logs to appear by clicking this [link](http://localhost) and refreshing
the page a few times

## Docker Clean Up
When running multiple stack updates or rebuilding stacks it is easy to build up a collection of dangling containers,
images and volumes that can be purged from your system. I use the following to perform a cleanup of my Docker environment.

```bash
# Delete all exited containers and their associated volume
docker ps --quiet --filter status=exited | xargs docker rm -v
# Delete all images, containers, volumes, and networks — that aren't associated with a container
docker system prune --force --volumes
```

:warning: Quite destructive commands follow...
```bash
# Delete all containers
docker ps --quiet --all | xargs docker rm -f
# Delete forcefully all images that match the name passed into the filter e.g. efk_*
docker image ls --quiet --filter 'reference=efk_*:*' | xargs docker rmi -f
# Delete everything? EVERYTHING!
docker system prune --all
```

## References
- [Docker Cleanup](https://www.digitalocean.com/community/tutorials/how-to-remove-docker-images-containers-and-volumes)
- [java-logger](https://github.com/DeploymentKing/java-logger)
- [Install Elasticsearch with Docker](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
- [ELK Docker Images](https://www.docker.elastic.co/)
- [Fluentd Quickstart](https://docs.fluentd.org/v1.0/articles/quickstart)

## Useful Articles
- [How To Centralize Your Docker Logs with Fluentd and ElasticSearch on Ubuntu 16.04](https://www.digitalocean.com/community/tutorials/how-to-centralize-your-docker-logs-with-fluentd-and-elasticsearch-on-ubuntu-16-04)
- [Free Alternative to Splunk Using Fluentd](https://docs.fluentd.org/v1.0/articles/free-alternative-to-splunk-by-fluentd)
