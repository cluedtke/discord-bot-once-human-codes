# discord-bot-once-human-codes

Not really a bot, but an AWS lambda to scrub a known steam discussion for Once Human codes and post to discord via webhook. Triggered once a day view AWS cloudwatch cron schedule.

## Deploy

```sh
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve -var "discord_webhook={{placeholder}}"
```
