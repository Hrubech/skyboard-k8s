FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html
# nginx:alpine fournit déjà l'utilisateur nginx (uid 101)
USER 101
EXPOSE 8080
