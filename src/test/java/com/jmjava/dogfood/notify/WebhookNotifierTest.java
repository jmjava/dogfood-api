package com.jmjava.dogfood.notify;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class WebhookNotifierTest {

    @Test
    void retrySendsDuplicateBodiesWithoutIdempotencyKey() {
        var notifier = new WebhookNotifier();
        var attempts = notifier.deliver("https://hooks.example/orders", "{\"order\":\"ord-100\"}");
        assertThat(attempts).hasSize(3);
        assertThat(attempts)
                .allMatch(delivery -> delivery.idempotencyKey() == null)
                .allMatch(delivery -> delivery.body().equals("{\"order\":\"ord-100\"}"));
    }
}
