package com.jmjava.dogfood.notify;

import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Unstructured-mode leftover. Retries a delivery without an idempotency key,
 * so a timeout can double-post. Not a Work ID — harvest as kind+area+body.
 */
@Component
public class WebhookNotifier {

    public List<Delivery> deliver(String url, String body) {
        List<Delivery> attempts = new ArrayList<>();
        for (int i = 0; i < 3; i++) {
            attempts.add(new Delivery(url, body, /* idempotencyKey */ null, i + 1));
        }
        return attempts;
    }

    public record Delivery(String url, String body, String idempotencyKey, int attempt) {
    }
}
