# Pushmi-Pullyu Docker Container Creation

**Warning: in progress; partially functional**


## What is this?

This directory contains the apparatus to create a Docker Container for the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) utility in both a development and production context. This container is meant to be used in conjunction with a [HydraNorth (Fedora and Solr)](https://github.com/ualbertalib/di_docker_hydranorth) container (source content layer) and an [OpenStack Swift](https://github.com/ualbertalib/DIDocker_Swift) container (i.e., preservation layer). For more details on inner workings of Pushmi-Pullyu see the [readme](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) at the root of the Pushmi-Pullyu repo - the idea, decouple components into minimalistic images each addressing a single concern allowing reuse.



## Requirements

* [Docker](https://docs.docker.com/engine/installation/) - tested with version 17.05
* [Docker Compose](https://docs.docker.com/compose/install/) - tested with version 1.13



## In this Docker Container

A minimalistic, as simple as possible but no simpler container.

### Development Environment Docker Container

* base off Ruby Docker image
* shared code directory between host and container
* start pushmi_pullyu at start-up


### Production Environment Docker Container

* base off Ruby Docker image
* pull from RubyGems
* start pushmi_pullyu at startup



## Usage

### Pushmi-Pullyu Development Option #1: HydraNorth (Solr/Fedora/Redis), Swift, and Pushmi-Pullyu networked

Goal: Development environment for Pushmi-Pullyu where the codebase on the host is shared with the Pushmi-Pullyu container. Docker-compose builds a network of three containers: Pushmi-Pullyu, HydyraNorth(Solr/Fedora/Redis), and Swift.


1. Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository
    * purpose: use to mount volume for HydraNorth docker container

2. Clone the [HydraNorth](https://github.com/ualbertalib/HydraNorth/) GitHub repository
    * purpose: use to mount volume for HydraNorth docker container

3. Update environment variables inside docker-compose-development.yml file.  These environment variables are defined in `pushmi_pullyu_config_docker.yml`.

4. Run Docker Compose
    * Development:
      * docker-compose -f docker/docker-compose-development.yml up -d
        * or without `-d` if one want the interactive mode where ctrl-c will shutdown the containers

5. Enter the `HydraNorth` container and update the `/etc/redis/redis.conf` with `bind 127.0.0.1 hydra-north` and restart `redis` (to bind Redis to an interface reachable via another container on the same network i.e., bind to interface other than localhost).
    * Note: restarting `redis` might require `kill -kill` if `service redis-server restart` fails
    * `docker exec -it docker_hydranorth_1 bash`
    * reference: [GitHub issue](https://github.com/ualbertalib/di_docker_hydranorth/issues/12)

6. Test redis by entering the `pushmi-pullyu` container and inspect the pushmi-pullyu log `/app/log/pushmi_pullyu.log` or try the command `telnet hydranorth 6379`
    * `docker exec -it docker_pushmi-pullyu_1 bash`
    * note: networking setup by docker compose allows referencing containers by their service names as defined in the `docker-compose-development.yml` file

7. Within the Pushmi-Pullyu container: to start the daemon
    * `bundle exec pushmi_pullyu start -C docker/files/pushmi_pullyu_config_docker.yml`
    * `pushmi_pullyu start -C docker/files/pushmi_pullyu_config_docker.yml`

8. Within the Pushmi-Pullyu container: to run tests:
   * `rspec`


#### Notes:

* Within a container, the following DNS entries are available: swift, hydranorth, pushmi-pullyu (e.g., ping swift)
* From outside the container, access either via:
  * Mapped ports to the host as defined in `docker-compose-development.yml`
    * E.g., `http://localhost:3000`
  * `container_IP`
    * E.g., `http://172.18.0.3:3000` (IP is a sample)


### Pushmi-Pullyu Development Option #2: Hydranorth (Solr/Fedora/Redis) and Swift networked

Goal: like option #1 but using only two containers: one for HydraNorth and the other for Swift with HydraNorth mounting the Pushmi-Pullyu codebase due to the Redis localhost rspec assumption

* **Warning:** workaround for the Redis bind localhost only restriction described in option #1.  [Reference GitHub issue](https://github.com/ualbertalib/di_docker_hydranorth/issues/12).
* **Warning:** without REDIS_URL, rspec test fail as they assume Redis runs on localhost. [Reference](https://github.com/redis/redis-rb).

1. Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository
    * purpose: use to mount volume for HydraNorth docker container

2. Clone the [HydraNorth](https://github.com/ualbertalib/HydraNorth/) GitHub repository
    * purpose: use to mount volume for HydraNorth docker container

3. Copy example `.env-hydranorth_example` to `.env-hydranorth` and update with environment variables
    * LOCAL_SRC_PATH: location of codebase in step #2.
    * EZID_PASSWORD: EZID password.

4. Copy example `.env-pushmi_pullyu` to `.env-pushmi_pullyu` and update with environment variables. These environment variables are defined in `pushmi_pullyu_config_docker.yml`. Defaults will work except for the following:
    * FEDORA_USER
    * FEDORA_PASS

5. Run Docker Compose
    * Development:
      * docker-compose -f docker/docker-compose-development-hydranorth.yml up -d
        * or without `-d` if one want the interactive mode where ctrl-c will shutdown the containers
      * `app_pushmi-pullyu` application directory

6. Run tests
    * `docker exec -it docker_hydranorth_1  sh -c "cd /app_pushmi-pullyu; bundle install; rspec;"`



### Pushmi-Pullyu image creation

Work with Pushmi-Pullyu in isolation

First usage:

1. Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository

2. Acquire the Docker image in one of two ways:
    1. Download the prebuilt images from [ualibraries DockerHub](https://hub.docker.com/r/ualibraries/)
        * Development
          * `docker pull ualibraries/pushmi-pullyu:development_x.x`
        * Production
          * `docker pull ualibraries/pushmi-pullyu:production_x.x`
    2. Build from `Dockerfile` definition in [Pushmi-pullyu GitHub repo](https://github.com/ualbertalib/pushmi_pullyu/docker)
        * Development:
          * `docker build -t ualibraries/pushmi_pullyu:development_x.x -f Dockerfile.pushmi_pullyu.development .`
        * Production:
          * `docker build -t ualibraries/pushmi_pullyu:production_x.x -f Dockerfile.pushmi_pullyu.production .`

3. Run the Docker image
    * Development:
      * `docker run -d -v $PUSHMI_PULLYU_DIR:/mnt --name pushmi_pullyu ualibraries/pushmi_pullyu:development`
    * Production:
      * `docker run -d -v $PUSHMI_PULLYU_DIR:/mnt --name pushmi_pullyu ualibraries/pushmi_pullyu:development`


After initial `docker run`:

  * Exec shell within container
    * `docker exec -it ${container_id}  bash`
  * `docker stop ${container_id}`
  * `docker start ${container_id}`




### Pushmi-Pullyu Docker Compose Usage

1. Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository

2. Grab the prebuilt images from [ualibraries DockerHub](https://hub.docker.com/r/ualibraries/)
    * Development
      * docker-compose -f docker/docker-compose-development.yml pull
    * Production
      * docker-compose -f docker/docker-compose-production.yml pull

3. Run the Docker Compose
    * Development:
      * docker-compose -f docker/docker-compose-development.yml up -d
    * Production:
      * docker-compose -f docker/docker-compose-production.yml up -d


**[ToDo] possibly wrong**
From inside the clone of the GitHub pushmi-pullyu/docker directory
  * `docker-compose up` to start the container (i.e., pushmi-pullyu stack)
  * **ToDo** does one need to be inside the directory or is this dependent on the .env file? "Compose supports declaring default environment variables in an environment file named .env placed in the folder where the docker-compose command is executed (current working directory)." [reference](https://docs.docker.com/compose/env-file/)


### Rake tasks

* Shell access within the container
  * `docker exec -it ${container_id}  bash`

**ToDo** add test rake tasks and other useful things to see within the container


### Debugging

Start a docker container and execute `bash` within container allowing user to test commands:

* `docker run -v ${path_to_github_clone_source_code}:/mnt -it  ruby:2.3.4  bash;`


## Maintenance

### Updating Docker Hub

**ToDo: need to flesh-out details**

University of Alberta maintains a Docker Hub repository at https://hub.docker.com/r/ualibraries. Two tagged Docker images are registered with Docker Hub:

1. Development
    * ualibraries/pushmi_pullyu:development_x.x
2. Production
    * ualibraries/pushmi_pullyu:production_x.x

#### To update the Docker Hub repository:

1. name your local using the `ualibraries` username and the repository name [reference](https://docs.docker.com/docker-hub/repos/#pushing-a-repository-image-to-docker-hub)
    * Development:
      * `docker build -t ualibraries/pushmi_pullyu:development_x.x -f Dockerfile.pushmi_pullyu.development .`
    * Production:
      * `docker build -t ualibraries/pushmi_pullyu:production_x.x -f Dockerfile.pushmi_pullyu.production .`

2. push to the Docker Hub registry - `docker push <hub-user>/<repo-name>:<tag>`
    * Development:
      * `docker push ualibraries/pushmi_pullyu:development_x.x`
    * Production:
      * `docker push ualibraries/pushmi_pullyu:production_x.x`



### Upgrading local Pushmi-Pullyu container

To upgrade to a newer release of Pushmi-Pullyu (applicable in the `production` container as the `development` container leverages a local codebase):

* download the updated Docker image:
  * `docker pull ualibraries\pushmi_pullyu:${production_x.x|development_x.x}`

* stop currently running image:
  * `docker stop ${container_id}`

* Removed the stopped container:
  * `docker rm -v ${container_id}`

* Start the updated Docker image:
  * `docker run ...`



## Frequently used commands

* Link to [Developer Handbook](https://github.com/ualbertalib/Developer-Handbook/blob/master/docker/README.md#Frequently-used-commands)


## Special notes / warnings / gotchas

* n/a

## Future considerations

* **Warning:** workaround for the Redis bind localhost only restriction described in option #1.  [Reference GitHub issue](https://github.com/ualbertalib/di_docker_hydranorth/issues/12).
* **Warning:** without REDIS_URL, rspec test fail as they assume Redis runs on localhost. [Reference](https://github.com/redis/redis-rb).
