package com.aasha.web.config;

import com.aasha.web.entity.AppUser;
import com.aasha.web.repository.UserRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserRepository userRepo;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter, UserRepository userRepo) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.userRepo = userRepo;
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> {
            var userOpt = userRepo.findByEmail(email);
            if (userOpt.isEmpty()) {
                throw new UsernameNotFoundException("User not found: " + email);
            }
            AppUser user = userOpt.get();
            return new User(
                user.getEmail(),
                user.getPasswordHash(),
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().toUpperCase()))
            );
        };
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/api/**")
            )
            .authorizeHttpRequests(auth -> auth
                // All citizen pages - public (no login needed)
                .requestMatchers("/", "/search", "/critical", "/camps", "/about", "/health").permitAll()
                .requestMatchers("/css/**", "/js/**", "/images/**").permitAll()
                // Auth pages
                .requestMatchers("/login", "/register", "/logout").permitAll()
                // Public API
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/stats", "/api/camps").permitAll()
                // Image upload API
                .requestMatchers("/api/v1/images/**").permitAll()
                // Match API
                .requestMatchers("/api/v1/match/**").permitAll()
                // Saved search API (citizens save searches without login)
                .requestMatchers("/api/saved-searches/**").permitAll()
                // Webhook for n8n
                .requestMatchers("/api/webhook/**").permitAll()
                // All other API requests need auth
                .requestMatchers("/api/**").authenticated()
                // Everything else public
                .anyRequest().permitAll()
            )
            .formLogin(form -> form
                .loginPage("/login")
                .loginProcessingUrl("/login")
                .defaultSuccessUrl("/", true)
                .failureUrl("/login?error")
                .permitAll()
            )
            .logout(logout -> logout
                .logoutUrl("/logout")
                .logoutSuccessUrl("/login")
                .permitAll()
            )
            .userDetailsService(userDetailsService())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
