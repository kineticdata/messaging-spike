Channel genserver was dying because implicit acks were being sent to a queue who's subscriber specified no_ack: true. Is there a way to opt-out of these implicit acks?

Used `:sys.trace(chan)` on the channel process to discover why the genserver was dying.

Rabbit auto-delete queues don't get deleted unless they are subscribed to first. I was creating an auto-delete queue and then closing the channel effectively immediately and noticed that those queues were being persisted after closing the channel/connection.