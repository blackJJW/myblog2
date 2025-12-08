.PHONY: serve deploy

serve:
	hugo serve -D

deploy:
	sh ./deploy.sh