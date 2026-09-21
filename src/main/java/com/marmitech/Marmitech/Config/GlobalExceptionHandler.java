package com.marmitech.Marmitech.Config;

import java.util.HashMap;
import java.util.Map;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import com.marmitech.Marmitech.Exceptions.NotFoundException;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;

@Slf4j
@ControllerAdvice
public class GlobalExceptionHandler {

	//TRATAMENTO DE ERROS DE VALIDATIONS
	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<Map<String, String>> handle01(MethodArgumentNotValidException ex) {
		Map<String, String> erros = new HashMap<>();
		for (FieldError fildError : ex.getBindingResult().getFieldErrors()) {
			erros.put(fildError.getField(), fildError.getDefaultMessage());
		}
		return new ResponseEntity<Map<String, String>>(erros, HttpStatus.BAD_REQUEST);
	}

	//TRATAMENTO DE ERROS DE VALIDATIONS
	@ExceptionHandler(ConstraintViolationException.class)
	public ResponseEntity<Map<String, String>> handle02(ConstraintViolationException ex) {
		Map<String, String> erros = new HashMap<>();
		for (ConstraintViolation<?> violation : ex.getConstraintViolations()) {
			erros.put(violation.getPropertyPath().toString(), violation.getMessage());
		}
		return new ResponseEntity<Map<String, String>>(erros, HttpStatus.BAD_REQUEST);
	}

	//TRATAMENTO DE RECURSOS NÃO ENCONTRADOS
	@ExceptionHandler(NotFoundException.class)
	public ResponseEntity<String> handleNotFound(NotFoundException ex) {
		log.warn("Recurso não encontrado: {}", ex.getMessage());
		return new ResponseEntity<>(ex.getMessage(), HttpStatus.NOT_FOUND);
	}

	//TRATAMENTO DOS DEMAIS ERROS DA APLICAÇÃO E DE REGRAS DE NEGÓCIO
	@ExceptionHandler(Exception.class)
	public ResponseEntity<String> handle03(Exception ex) {
		log.error("Erro na aplicação: {}", ex.getMessage());
		return new ResponseEntity<String>(ex.getMessage(), HttpStatus.BAD_REQUEST);
	}

}