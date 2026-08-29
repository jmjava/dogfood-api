package com.jmjava.dogfood.auth;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AuthFilterTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void orderLookupStaysPublic() throws Exception {
        mvc.perform(get("/api/orders").param("email", "ops@example.com"))
                .andExpect(status().isOk());
    }

    @Test
    void adminWithoutKeyIsUnauthorized() throws Exception {
        mvc.perform(get("/api/admin/health"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminWithKeySucceeds() throws Exception {
        mvc.perform(get("/api/admin/health").header("X-Dogfood-Key", "dogfood"))
                .andExpect(status().isOk());
    }
}
