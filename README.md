# Introduction

The simplest way to get env variables to a browser based app

This all starts in the Dockerfile.  This project uses a multi-stage build to create a final 19MB nginx hosted React app.

The intermediate stage, turns into an orphan and unfortunately it is 441MB.  This orphan would not be created if I was using 
some sort of build automator - oh well for now.

# To Run

* open a terminal
* clone the repo
* edit and source the file: env_template.  Enter your hostname (e.g. IP_ADDRESS=localhost or IP_ADDRESS=192.168.17.6)
* issue: docker-compose -f compose.yml build
* followed by: docker-compose -f compose.yml up

From time to time, you will want to clean out your docker image cache.  Over time a large number of orphan images will accomulate and waste disk space.  TO go nuclear on the whole system use:

* docker system prune -a

To be more selective, use:

* docker images - which will show you a list of container ids
* docker rmi <container id>


# How does it work?

First, let's be clear, the browser does not know about environment variables.  These are a server side concept.

In the browser, these environment variables are simulated by the packager, webpack.  The React ecosystem has a convention, to prefix environment variables with "REACT_APP_".  What REALLY happens is webpack gathers up all of the environment (if you use unix / bash, what you get with the "set" cmd) and creates variables on the window object, which is exposed in the browser javascript run environment.  In your React code, you can investigate "process.env" and see a number of items.  Of course, you will see REACT_APP_* variables.

# How to set this up?

In the Dockerfile, the first stage, called builder, uses an alpine node image to build the React app.  This first stage simply: 

* establishes a WORKDIR of /app
* copy the package.json and package-lock.json into the WORKDIR
* installs the node dependencies from the package.json file (using a silent run)
* builds a production, minimized version of the application and places this in a directory called /app/build
* introduce an argument "REACT_APP_IP_ADDRESS"
* inject REACT_APP_IP_ADDRESS into the environment of the container

The second stage of the build then creates the final container image.  This stage:

* starts with nginx
* overlays a new config for nginx to use
* copies the /app/build dir from the first stage and places it so nginx can serve it as static files.
* open port 80 on the container
* run nginx

This is the Dockerfile

~~~

# => Build container
# ----------------  1st stage ------------------------
FROM node:alpine as builder
WORKDIR /app
COPY package.json .
COPY package-lock.json .
RUN npm i --silent

ARG REACT_APP_IP_ADDRESS

ENV REACT_APP_IP_ADDRESS $REACT_APP_IP_ADDRESS

COPY . .
RUN npm run build --silent

# build the final container that hosts the app from nginx
# ----------------  2nd stage ------------------------
FROM nginx:1.15.2-alpine

# Nginx config
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Static build from the previous builder stage
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
~~~

Lines 1-7 setup and install dependencies from package.json.

line 8-10 establish an environment variable: REACT_APP_IP_ADDRESS.

If you use docker build and then "rip" the image apart you could find the environment variables exposed.  But, what we want is to use docker-compose and pass these through to the application.

# How to setup docker-compose 

We eventually want to build this system with a CI/CD pipeline, like Jenkins or Earthly or Spinaker.  We do not want to depend on external scripts to magically fix IPs or anything else.

Eventially we'll run this system under NOMAD and Kubernetes, so we want our solution to depend only on docker and its configuration.  For example both NOMAD and the kubernetes ecosystems automatically translate docker-compose configuration files into helm charts (i.e. their internal configuration).

This is the compose file.

~~~

version: '3'
services:
  frontend:
    container_name: ui
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - REACT_APP_IP_ADDRESS=${IP_ADDRESS}
    ports:
      - "80:80"

~~~

Please notice that the compose file introduces an argument (with the ARGS verb).  In this case the ARGS reference something called ${IP_ADDRESS}.  That variable has to be exported (bash syntax) into the environment (export IP_ADDRESS=192.168.0.1 or export IP_ADDRESS=localhost).

# nginx

The nginx config file is nothing special.  It simply tells nginx to serve index.html files from it standard directoy. One key thing to note: the app is served and exposed on port 80, just like a standard web server.  The compose file tells docker to expose the container port 80 on the host port 80 so that a browser can hit http://localhost and recieve the app.  If you look at the log on the terminal you ran this from you will see all of the files in the build dir served.

~~~

server {

  listen 80;

  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
    try_files $uri $uri/ /index.html;
  }

  error_page   500 502 503 504  /50x.html;

  location = /50x.html {
    root   /usr/share/nginx/html;
  }

}

~~~