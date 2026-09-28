package com.nicoly.projeto_joias.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

public class PasswordUtils {

    public static String hashPassword(String rawPassword) {
        if (rawPassword == null) {
            return null;
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawPassword.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            throw new RuntimeException("Erro ao gerar hash da senha", e);
        }
    }

    public static boolean matches(String rawPassword, String storedPassword) {
        if (rawPassword == null || storedPassword == null) {
            return false;
        }
        if (rawPassword.equals(storedPassword)) {
            return true;
        }
        String hashedInput = hashPassword(rawPassword);
        return hashedInput != null && hashedInput.equalsIgnoreCase(storedPassword);
    }
}
