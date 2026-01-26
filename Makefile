.PHONY: serve deploy

serve:
	hugo serve -D

commit:
	git add .
	git commit -m "$(shell date '+%Y-%m-%d %H:%M:%S')"

deploy:
	sh ./deploy.sh