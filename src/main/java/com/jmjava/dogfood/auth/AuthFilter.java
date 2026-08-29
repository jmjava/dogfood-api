package com.jmjava.dogfood.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Existing auth behavior. FEAT-001 must not change this filter.
 * Admin routes stay key-gated; order lookup stays public.
 */
@Component
public class AuthFilter extends OncePerRequestFilter {

    private final String adminKey;

    public AuthFilter(@Value("${dogfood.admin-key:dogfood}") String adminKey) {
        this.adminKey = adminKey;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (request.getRequestURI().startsWith("/api/admin/")) {
            String provided = request.getHeader("X-Dogfood-Key");
            if (provided == null || !provided.equals(adminKey)) {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                return;
            }
        }
        filterChain.doFilter(request, response);
    }
}
