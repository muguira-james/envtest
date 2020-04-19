
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

