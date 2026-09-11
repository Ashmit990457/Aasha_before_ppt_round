package com.aasha.web.controller;

import com.aasha.web.dto.SearchRequest;
import com.aasha.web.entity.CriticalRecord;
import com.aasha.web.entity.NormalRecord;
import com.aasha.web.service.RecordService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Base64;
import java.util.List;

@Controller
public class SearchController {

    private static final Logger log = LoggerFactory.getLogger(SearchController.class);
    private final RecordService recordService;

    public SearchController(RecordService recordService) {
        this.recordService = recordService;
    }

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("stats", recordService.getStats());
        model.addAttribute("camps", recordService.getActiveCamps());
        return "home";
    }

    @GetMapping("/search")
    public String searchForm(Model model) {
        model.addAttribute("request", new SearchRequest());
        return "search";
    }

    @PostMapping("/search")
    public String search(@ModelAttribute SearchRequest request,
                         @RequestParam(value = "photoFile", required = false) MultipartFile photoFile,
                         Model model) {

        if (photoFile != null && !photoFile.isEmpty()) {
            try {
                byte[] bytes = photoFile.getBytes();
                request.setPhoto(Base64.getEncoder().encodeToString(bytes));
            } catch (Exception e) {
                log.error("Failed to encode photo", e);
            }
        }

        String name = request.getTrimmedName();
        Integer age = (request.getAge() != null && request.getAge() > 0) ? request.getAge() : null;

        List<NormalRecord> results = recordService.searchNormalRecords(name, age);
        model.addAttribute("results", results);
        model.addAttribute("searched", true);
        model.addAttribute("request", request);
        return "search";
    }

    @GetMapping("/critical")
    public String criticalForm(@RequestParam(value = "name", required = false) String name,
                               @RequestParam(value = "age", required = false) Integer age,
                               Model model) {
        SearchRequest request = new SearchRequest();
        if (name != null) request.setName(name);
        if (age != null && age > 0) request.setAge(age);

        model.addAttribute("request", request);

        if (request.hasName() || (request.getAge() != null && request.getAge() > 0)) {
            String searchName = request.getTrimmedName();
            Integer searchAge = (request.getAge() != null && request.getAge() > 0) ? request.getAge() : null;
            List<CriticalRecord> results = recordService.searchCriticalRecords(searchName, searchAge);
            model.addAttribute("results", results);
            model.addAttribute("searched", true);
        }
        return "critical";
    }

    @PostMapping("/critical")
    public String criticalSearch(@ModelAttribute SearchRequest request, Model model) {
        String name = request.getTrimmedName();
        Integer age = (request.getAge() != null && request.getAge() > 0) ? request.getAge() : null;

        List<CriticalRecord> results = recordService.searchCriticalRecords(name, age);
        model.addAttribute("results", results);
        model.addAttribute("searched", true);
        model.addAttribute("request", request);
        return "critical";
    }

    @GetMapping("/camps")
    public String campsPage(@RequestParam(value = "q", required = false) String query, Model model) {
        model.addAttribute("camps", recordService.searchCamps(query));
        model.addAttribute("query", query);
        return "camps";
    }

    @GetMapping("/about")
    public String aboutPage(Model model) {
        model.addAttribute("stats", recordService.getStats());
        return "about";
    }

    @GetMapping("/health")
    @ResponseBody
    public java.util.Map<String, Object> health() {
        return java.util.Map.of(
            "status", "ok",
            "web", "ok",
            "database", "connected"
        );
    }
}
