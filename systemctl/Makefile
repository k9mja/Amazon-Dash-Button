
all: install

.PHONY: status install

status:
	systemctl status amazon-dash-button.service

install: 
	install -m 0644 amazon-dash-button.service /lib/systemd/system/
	systemctl daemon-reload
	systemctl enable amazon-dash-button.service
	systemctl restart amazon-dash-button.service
	systemctl status amazon-dash-button.service
