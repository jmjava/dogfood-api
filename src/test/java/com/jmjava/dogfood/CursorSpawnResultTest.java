package com.jmjava.dogfood;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.fail;

/**
 * Feeds the Cursor-day verdict into {@code ./mvnw test}.
 * A finished spawn is not enough: status.sh must have recorded RESULT=WORKED
 * (gate, pointer, unstructured lesson, no FEAT-ADHOC).
 *
 * Default CI has no receipt → this test is skipped.
 * {@code run.sh} sets {@code DOGFOOD_REQUIRE_CURSOR_SPAWN=1} so a failed day
 * fails Maven with the WHY line.
 */
class CursorSpawnResultTest {

    @Test
    void actualCursorDayWorked() throws Exception {
        Path result = Path.of(
                env("DOGFOOD_AGENT_RESULT", "sdlc-spdd/.sdlc/agent-day-result.txt"));
        boolean require = Boolean.parseBoolean(env("DOGFOOD_REQUIRE_CURSOR_SPAWN", "false"));
        if (!Files.exists(result)) {
            if (require) {
                fail("Cursor day FAILED: WHY=no-result (status.sh did not write "
                        + result + "). The test did not run or did not record an outcome.");
            }
            Assumptions.assumeTrue(false, "Cursor day not run in this pass (no " + result + ")");
            return;
        }
        String text = Files.readString(result);
        if (!text.contains("RESULT=WORKED")) {
            String why = text.lines()
                    .filter(line -> line.startsWith("WHY="))
                    .collect(Collectors.joining("\n"));
            if (why.isBlank()) {
                why = "WHY=unknown\n" + text;
            }
            fail("Cursor day FAILED (not just spawn — the day outcomes failed):\n" + why + "\n" + text);
        }
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }
}
