FROM rabbitmq:3.11-management

COPY ./plugins/rabbitmq_delayed_message_exchange-3.11.1.ez /plugins

RUN rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange