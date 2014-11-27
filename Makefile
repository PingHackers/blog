all: init

init:
	npm install -g hexo
	npm install
	git clone https://github.com/xiangming/landscape-plus.git themes/landscape-plus

dev: 
	hexo clean && hexo generate && hexo server

build: init 
	./deploy
