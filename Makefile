SHELL=/bin/bash
api-server/%: ## api-server/${lang}docker-compose up with mysql and api-server 
	docker-compose -f docker-compose/$(shell basename $@).yaml down -v
	docker-compose -f docker-compose/$(shell basename $@).yaml up --build mysql api-server

isuumo/%: ## isuumo/${lang} docker-compose up with mysql and api-server frontend nginx
	docker-compose -f docker-compose/$(shell basename $@).yaml down -v
	docker-compose -f docker-compose/$(shell basename $@).yaml up --build mysql api-server nginx frontend

WEBHOOK_URL=https://discord.com/api/webhooks/993867060528549928/79xOfLjqv1PHuwyP6JCZeO2ShK4pHdL9qJSCOh7v5xd5bZIwhu-g4tWVR9MpP-7oE_0k

.PHONY: build
build:
	cd /home/isucon/isuumo/webapp/go; \
	go build -o isuumo main.go; \
	sudo systemctl restart isuumo.go.service;

.PHONY: alp
alp:
	sudo cat /var/log/nginx/access.log | alp ltsv -m '/api/chair/[0-9]+,/api/estate/[0-9]+,/api/chair/buy/[0-9]+,/api/estate/req_doc/[0-9]+,/api/recommended_estate/[0-9],/_next/static/*' --sort avg -r > alp_log.txt
	sudo mv alp_log.txt /temp/alp_log.txt
	curl -X POST -F alp_log=@/temp/alp_log.txt ${WEBHOOK_URL}

.PHONY: slow-show
slow-show:
	# sudo mysqldumpslow -s t -t 10 > mysqldumpslow_log.txt
	sudo pt-query-digest /var/log/mysql/mysql-slow.log > pt-query-digest_log.txt
	# sudo mv mysqldumpslow_log.txt /temp/mysqldumpslow_log.txt
	sudo mv pt-query-digest_log.txt /temp/pt-query-digest_log.txt
	# curl -X POST -F mysqldumpslow_log=@/temp/mysqldumpslow_log.txt ${WEBHOOK_URL}
	curl -X POST -F pt-query-digest_log=@/temp/pt-query-digest_log.txt ${WEBHOOK_URL}

.PHONY: pprof
pprof:
	go tool pprof -http=0.0.0.0:8080 /home/isuumo/webapp/go/isuumo http://localhost:6060/debug/pprof/profile
.PHONY: pprof-image
pprof-image:
	go tool pprof -png -output pprof.png http://localhost:6060/debug/pprof/profile
	sudo mv pprof.png /temp/pprof.png
	curl -X POST -F pprof=@/temp/pprof.png ${WEBHOOK_URL}

.PHONY: truncate
truncate:
	sudo truncate -s 0 -c /var/log/nginx/access.log
	sudo rm -f /var/log/mysql/mysql-slow.log

.PHONY: restart-mysql
restart-mysql:
	sudo systemctl restart mysql.service
.PHONY: restart-nginx
restart-nginx:
	sudo systemctl restart nginx

.PHONY: setting-mysql
setting-mysql:
	sudo nano /etc/mysql/my.cnf
.PHONY: setting-nginx
setting-nginx:
	sudo nano /etc/nginx/nginx.conf

.PHONY: pre-bench
pre-bench:
	make restart-mysql
	make restart-nginx
	make build
	make truncate
.PHONY: after-bench
after-bench:
	make alp
	make slow-show