# Pushmi-Pullyu Docker Container Creation #

## What is this? ##

This directory contains the apperatus to create a Docker Container for the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) utility in both a development and production context. This container is meant to be used in conjuction with a [HydraNorth (Fedora and Solr)](https://github.com/ualbertalib/di_docker_hydranorth) container (source content layer) and an [OpenStack Swift](https://github.com/ualbertalib/DIDocker_Swift) container (i.e., preservation layer). For more details on inner workings of Pushmi-Pullyu see the [readme](https://github.com/ualbertalib/pushmi_pullyu/blob/master/README.md) at the root of the Pushmi-Pullyu repo.



## Requirements ##

* [Docker](https://docs.docker.com/engine/installation/) - tested with version 17.05 
* [Docker Compose](https://docs.docker.com/compose/install/) - tested with version 1.13



## In this Docker Container ##

A minimalistic, as simple as possible but no simpler container. 

### Development Environment Docker Container ###

* base off Ruby Docker image
* shared code directory between host and container 
* start pushmi_pullyu at startup


### Production Environment Docker Container ###

* base off Ruby Docker image
* pull from RubyGems
* start pushmi_pullyu at startup



## Usage ##

### Container creation ###

(1) Clone the [Pushmi-Pullyu](https://github.com/ualbertalib/pushmi_pullyu/) GitHub repository

**ToDo** is there a dot_env file? If yes, use to define env vars to pass to DockerFile. Create `.env` that is in the .gitignore list and a dotenv.example to build from. 

(2) Download the prebuilt images from [ualibraries DockerHub](https://hub.docker.com/r/ualibraries/) 
    * Development
      * `docker-compose pull ualibraries/pushmi-pullyu:development_x.x
    * Production 
      * `docker-compose pull ualibraries/pushmi-pullyu:production_x.x

(3) From inside the clone of the GitHub pushmi-pullyu/docker directory
  * `docker-compose up` to start the container (i.e., pushmi-pullyu stack) 
  * **ToDo** does one need to be inside the directory or is this dependent on the .env file? "Compose supports declaring default environment variables in an environment file named .env placed in the folder where the docker-compose command is executed (current working directory)." [reference](https://docs.docker.com/compose/env-file/)


### Rake tasks ###

* Shell access within the container
  * docker exec -it ${container_id}  bash 

**ToDo** add test rake tasks and other useful things to see within the container



## Maintenance ##

### Updating DockerHub ###

University of Alberta maintains a Docker Hub repository at https://hub.docker.com/r/ualibraries. Two Docker images are registered with Docker Hub:

(1) Development 
  * ualibraries/pushmi_pullyu:development_x.x
(2) Production 
  * ualibraries/pushmi_pullyu:production_x.x

To push to a Docker Hub repository:

(1) name your local using the `ualibraries` username and the repository name [reference](https://docs.docker.com/docker-hub/repos/#pushing-a-repository-image-to-docker-hub)
  * Development:
    * `docker build -t ualibraries/pushmi_pullyu:development_x.x -f Dockerfile.pushmi_pullyu.development .` 
  * Production:
    * `docker build -t ualibraries/pushmi_pullyu:production_x.x -f Dockerfile.pushmi_pullyu.production .` 

(2) push to the Docker Hub registry - `docker push <hub-user>/<repo-name>:<tag>`
  * Development:
    * `docker push ualibraries/pushmi_pullyu:development_0.0` 
  * Production:
    * `docker push ualibraries/pushmi_pullyu:production_0.0` 



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

* Shell access
  * docker exec -it ${container_id}  bash 

* Low-level container information 
  * docker inspect ${container_id}

* Display container log files 
  * docker logs --details --follow ${container_id}

* Remove containers and associated volumes
  * docker rm --volumes

* List containers
  * docker ps --all --size

* Network listing
  * docker network ls

* Other Docker CLI commands
  * [Docker documentation](https://docs.docker.com/engine/reference/commandline/docker/)


* to see the container(s) logs
  * docker-compose logs ${container_id} 

* to build the image(s) from scratch
  * docker-compose build --no-cache <service_name> 

* Allow a non-root user to administer Docker
  * add user to the `docker` group
  * warning, only add trusted users - [reference](https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface) - allows the user to share a directory between the Docker host and guest container without limiting access rights (i.e., it will have root level access to the shared directory). Requiring `sudo` to start Docker leaves a log trail. 


## Future considerations ##

* [Configure automated builds on Docker Hub](https://docs.docker.com/docker-hub/builds/)

* don't use the Docker Hub ":latest" tag because "the last build/tag that ran without a specific tag/version specified" [reference](https://medium.com/@mccode/the-misunderstood-docker-tag-latest-af3babfd6375)

* link/depends_on in docker-compose to handle dependencies and determine the order of service startup. 
  * [links](https://docs.docker.com/compose/compose-file/compose-file-v2/#links)
  * [depends_on](https://docs.docker.com/compose/compose-file/compose-file-v2/#dependson)

* Terminology
  * Docker container versus image
    * image: created by the build process, stored in Docker Hub registry, inert, essentially a snapshot of a container
    * container: running instance of an image
