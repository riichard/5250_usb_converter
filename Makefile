PI      := pdp11
RDIR    := /home/pi/dev/5250_usb_converter

.PHONY: deploy install status logs restart stop start discover-arrows

# Copy changed files and restart the service
deploy:
	ssh $(PI) "mkdir -p $(RDIR)/etc"
	scp 5250_terminal.py $(PI):$(RDIR)/
	scp -r etc/ $(PI):$(RDIR)/
	ssh $(PI) "systemctl list-unit-files ibm5250.service --no-pager | grep -q ibm5250 && sudo systemctl restart ibm5250.service || echo '(service not yet installed; run: make install)'"
	ssh $(PI) "systemctl list-unit-files ibm5250.service --no-pager | grep -q ibm5250 && sudo systemctl status ibm5250.service --no-pager || true"

# Full install: copy everything and run install.sh (use after fresh clone or
# when the service file, kbdhelp, or sudoers need updating)
install:
	ssh $(PI) "mkdir -p $(RDIR)/etc $(RDIR)/systemd"
	scp 5250_terminal.py $(PI):$(RDIR)/
	scp -r etc/ $(PI):$(RDIR)/
	scp systemd/install.sh $(PI):$(RDIR)/systemd/
	scp systemd/ibm5250.service $(PI):$(RDIR)/systemd/
	ssh $(PI) "cd $(RDIR) && sudo bash systemd/install.sh"

status:
	ssh $(PI) "sudo systemctl status ibm5250.service --no-pager"

logs:
	ssh $(PI) "journalctl -u ibm5250.service -f"

restart:
	ssh $(PI) "sudo systemctl restart ibm5250.service"

stop:
	ssh $(PI) "sudo systemctl stop ibm5250.service"

start:
	ssh $(PI) "sudo systemctl start ibm5250.service"

# Stop the service and run the script interactively in connection-debug mode.
# Press each physical arrow key at the 5250> prompt to reveal its scancode.
discover-arrows:
	ssh -t $(PI) "sudo systemctl stop ibm5250.service && cd $(RDIR) && python3 -u 5250_terminal.py -c"
