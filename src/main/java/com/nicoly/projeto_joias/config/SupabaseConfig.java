package com.nicoly.projeto_joias.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class SupabaseConfig {

    @Value("${supabase.rest.url:https://pssrggtqmphcpqbdhjex.supabase.co/rest/v1/}")
    private String supabaseRestUrl;

    @Value("${supabase.secret.key:}")
    private String supabaseSecretKey;

    @Bean
    public RestClient supabaseRestClient() {
        return RestClient.builder()
                .baseUrl(supabaseRestUrl)
                .defaultHeader("apikey", supabaseSecretKey)
                .defaultHeader("Authorization", "Bearer " + supabaseSecretKey)
                .defaultHeader("Content-Type", "application/json")
                .defaultHeader("Accept", "application/json")
                .build();
    }
}
