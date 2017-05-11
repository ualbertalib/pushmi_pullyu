# Pushmi-Pullyu Docker Container Creation #

## What is this? ##

This directory contains the apparatus to create a Docker Container for the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) utility in both a development and production context. This container is meant to be used in conjunction with a [HydraNorth (Fedora and Solr)](https://github.com/ualbertalib/di_docker_hydranorth) container (source content layer) and an [OpenStack Swift](https://github.com/ualbertalib/DIDocker_Swift) container (i.e., preservation layer). For more details on inner workings of Pushmi-Pullyu see the [readme](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) at the root of the Pushmi-Pullyu repo - the idea, decouple components into minimalistic images each addressing a single concern allowing reuse.



## Requirements ##

* [Docker](https://docs.docker.com/engine/installation/) - tested with version 17.05 
* [Docker Compose](https://docs.docker.com/compose/install/) - tested with version 1.13



## In this Docker Container ##

A minimalistic, as simple as possible but no simpler container. 

### Development Environment Docker Container ###

* base off Ruby Docker image
* shared code directory between host and container 
* start pushmi_pullyu at start-up


### Production Environment Docker Container ###

* base off Ruby Docker image
* pull from RubyGems
* start pushmi_pullyu at startup



## Usage ##

### Pushmi-Pully Usage ###

*ToDo*

Add Docker Compose usage once written. 

The below is a placeholder


### Pushmi-Pullyu image creation ###

Work with Pushmi-Pullyu in isolation

First usage:

  (1) Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository

  (2) Acquire the Docker image in one of two ways:
    (a) Download the prebuilt images from [ualibraries DockerHub](https://hub.docker.com/r/ualibraries/) 
      * Development
        * `docker pull ualibraries/pushmi-pullyu:development_x.x`
      * Production 
        * `docker pull ualibraries/pushmi-pullyu:production_x.x`
    (b) Build from `Dockerfile` definition in [Pushmi-pullyu GitHub repo](https://github.com/ualbertalib/pushmi_pullyu/docker) 
      * Development:
        * `docker build -t ualibraries/pushmi_pullyu:development_x.x -f Dockerfile.pushmi_pullyu.development .` 
      * Production:
        * `docker build -t ualibraries/pushmi_pullyu:production_x.x -f Dockerfile.pushmi_pullyu.production .` 

  (3) Run the Docker image 
      * Development:
        * docker run -d -v $PUSHMI_PULLYU_DIR:/mnt --name pushmi_pullyu ualibraries/pushmi_pullyu:development
      * Production:
        * docker run -d -v $PUSHMI_PULLYU_DIR:/mnt --name pushmi_pullyu ualibraries/pushmi_pullyu:development


After initial `docker run`:

  * Exec shell within container
    * docker exec -it ${container_id}  bash
  * docker stop ${container_id}
  * docker start ${container_id}




### Pushmi-Pullyu Docker Compose Usage ###

(1) Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository

**ToDo** is there a dot_env file? If yes, use to define env vars to pass to DockerFile. Create `.env` that is in the .gitignore list and a dotenv.example to build from. 

(2) Acquire the Docker images :
  (a) Download the prebuilt images from [ualibraries DockerHub](https://hub.docker.com/r/ualibraries/) 
    * Development
      * docker-compose -f docker-compose-development.yml pull 
    * Production 
      * docker-compose -f docker-compose-production.yml pull

(3) Run the Docker Compose 
    * Development:
      * docker-compose -f docker-compose-development.yml up -d 
    * Production:
      * docker-compose -f docker-compose-production.yml up -d 



(3) From inside the clone of the GitHub pushmi-pullyu/docker directory
  * `docker-compose up` to start the container (i.e., pushmi-pullyu stack) 
  * **ToDo** does one need to be inside the directory or is this dependent on the .env file? "Compose supports declaring default environment variables in an environment file named .env placed in the folder where the docker-compose command is executed (current working directory)." [reference](https://docs.docker.com/compose/env-file/)


### Rake tasks ###

* Shell access within the container
  * docker exec -it ${container_id}  bash 

**ToDo** add test rake tasks and other useful things to see within the container


### Debugging ###

Start a docker container and execute `bash` within container allowing user to test commands:

* `docker run -v ${path_to_github_clone_source_code}:/mnt -it  ruby:2.3.4  bash;`


## Maintenance ##

### Updating Docker Hub ###

University of Alberta maintains a Docker Hub repository at https://hub.docker.com/r/ualibraries. Two Docker images are registered with Docker Hub:

(1) Development 
  * ualibraries/pushmi_pullyu:development_x.x
(2) Production 
  * ualibraries/pushmi_pullyu:production_x.x

#### To update the Docker Hub repository: ####

(1) name your local using the `ualibraries` username and the repository name [reference](https://docs.docker.com/docker-hub/repos/#pushing-a-repository-image-to-docker-hub)
  * Development:
    * `docker build -t ualibraries/pushmi_pullyu:development_x.x -f Dockerfile.pushmi_pullyu.development .` 
  * Production:
    * `docker build -t ualibraries/pushmi_pullyu:production_x.x -f Dockerfile.pushmi_pullyu.production .` 

(2) push to the Docker Hub registry - `docker push <hub-user>/<repo-name>:<tag>`
  * Development:
    * `docker push ualibraries/pushmi_pullyu:development_x.x` 
  * Production:
    * `docker push ualibraries/pushmi_pullyu:production_x.x` 



### Upgrading local Pushmi-Pullyu container ###

To upgrade to a newer release of Pushmi-Pullyu (applicable in the `production` container as the `development` container leverages a local codebase):

* download the updated Docker image:
  * `docker pull ualibraries\pushmi_pullyu:${production_x.x|development_x.x}` 

* stop currently running image:
  * `docker stop ${container_id}` 

* Removed the stopped container:
  * `docker rm -v ${container_id}` 

* Start the updated Docker image: 
  * `docker run ...`



## Frequently used commands ##

* to see the container(s) logs
  * docker-compose logs ${container_id} 

* to build the image(s) from scratch
  * docker-compose build --no-cache <service_name> 

* Link to [Developer Handbook](https://github.com/ualbertalib/Developer-Handbook/blob/master/docker/README.md#Frequently-used-commands)


## Special notes / warnings / gotchas


## Future considerations ##
