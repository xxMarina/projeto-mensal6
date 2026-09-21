package com.marmitech.Marmitech.DTO.ResponseDTO;

public record LoginResponseDTO(
    String token,
    String tipo,
    UsuarioResponseDTO usuario
) {}
