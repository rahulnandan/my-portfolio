package com.rahulnandan.portfolio.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "resume")
public record ResumeProperties(
        String name,
        String title,
        String location,
        String email,
        String phone,
        String linkedin,
        String summary,
        List<SkillGroup> skillGroups,
        List<ExperienceEntry> experience,
        List<String> certifications,
        List<EducationEntry> education) {

    public record SkillGroup(String category, String items) {
    }

    public record ExperienceEntry(
            String title, String company, String location, String period, List<String> bullets) {
    }

    public record EducationEntry(String degree, String institution, String period) {
    }
}
