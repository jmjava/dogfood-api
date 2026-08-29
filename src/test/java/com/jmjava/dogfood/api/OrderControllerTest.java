package com.jmjava.dogfood.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class OrderControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void lookupByEmailReturnsMatches() throws Exception {
        mvc.perform(get("/api/orders").param("email", "ops@example.com"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].customerEmail").value("ops@example.com"));
    }

    @Test
    void invalidEmailReturns400() throws Exception {
        mvc.perform(get("/api/orders").param("email", "not-an-email"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void emptyResultReturns200() throws Exception {
        mvc.perform(get("/api/orders").param("email", "nobody@example.com"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }
}
