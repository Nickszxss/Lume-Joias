package com.nicoly.projeto_joias.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class SupabaseConfig {

    @Value("${supabase.url:https://pssrggtqmphcpqbdhjex.supabase.co/rest/v1}")
    private String supabaseUrl;

    @Value("${supabase.key:sb_publishable_p9yLQDR5lj0uT0F5NQ1_aw_6TyS9job}")
    private String supabaseKey;

    @Bean
    public RestClient supabaseRestClient() {
        return RestClient.builder()
                .baseUrl(supabaseUrl)
                .defaultHeader("apikey", supabaseKey)
                .defaultHeader("Authorization", "Bearer " + supabaseKey)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }
}
