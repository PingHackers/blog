all: init

init:
	npm install -g hexo
	npm install

dev: 
	hexo clean && hexo generate && hexo server

build: init 
	./deploy
