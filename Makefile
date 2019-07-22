PROJECT = aws_iot_client
PROJECT_DESCRIPTION = New project
PROJECT_VERSION = 0.1.0

DEPS = emqttc
dep_emqttc = git https://github.com/rabbitmq/emqttc.git remove-logging

include erlang.mk
