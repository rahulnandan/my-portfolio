package com.rahulnandan.portfolio.controller;

import com.rahulnandan.portfolio.config.ResumeProperties;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class PortfolioController {

    private final ResumeProperties resume;

    public PortfolioController(ResumeProperties resume) {
        this.resume = resume;
    }

    @GetMapping("/")
    public String index(Model model) {
        model.addAttribute("resume", resume);
        return "index";
    }
}
