# Introduction

The simplest way to get env variables to a browser based app

This all starts in the Dockerfile.  This project uses a multi-stage build to create a final 19MB nginx hosted React app.

The intermediate stage, turns into an orphan and unfortunately it is 441MB.  This orphan would not be created if I was using 
some sort of build automator - oh well for now.

# How does it work?

First, let's be clear, the browser does not know about environment variables.  These are a server side concept.

In the browser, these environment variable are simulated by the packager, webpack.  The React ecosystem has a convention, to prefix environment variables with "REACT_APP_".  What REALLY happens is webpack gathers up all of the environment (if you use unix / bash, what you get with the "set" cmd) and creates variables on the window object, which is exposed in the browser javascript run environment.  In your React code, you can investigate "process.env" and see a number of items.  Of course you will see REACT_APP_* variables.

# How to set this up?

In the Dockerfile, the first stage, called builder, uses an alpine node image to build the React app.

This is the Dockerfile

~~~

# => Build container
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
    # environment:
    #     - REACT_APP_IP_ADDRESS
    ports:
      - "80:80"

~~~