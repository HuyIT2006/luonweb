package com.kinhdoanh.luonweb.exception;

import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public String handleException(Exception ex, Model model) {
        model.addAttribute("errorTitle", "Có lỗi xảy ra");
        model.addAttribute("errorMessage", ex.getMessage() != null ? ex.getMessage() : "Lỗi không xác định");
        return "error";
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public String handleIllegalArgumentException(IllegalArgumentException ex, Model model) {
        model.addAttribute("errorTitle", "Tham số không hợp lệ");
        model.addAttribute("errorMessage", ex.getMessage());
        return "error";
    }
}
