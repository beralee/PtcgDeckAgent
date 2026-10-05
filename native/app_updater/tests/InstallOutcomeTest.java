package cn.skillserver.ptcg.updater;

public final class InstallOutcomeTest {
    public static void main(String[] args) {
        expect("success", 0, 0, false);
        expect("failed_3", 3, -115, false); // Android abort is not proof the player cancelled.
        expect("failed_verification", 3, -22, false);
        expect("failed_verification", 3, 0, true);
        expect("failed_2", 2, 0, false);
        expect("failed_6", 6, 0, false);
        expect("failed_99", 99, 0, false);
        System.out.println("PASS 7 install outcome cases");
    }
    private static void expect(String expected, int status, int legacy, boolean verification) {
        String actual = InstallOutcome.status(status, legacy, verification);
        if (!expected.equals(actual)) throw new AssertionError(expected + " != " + actual);
    }
}
