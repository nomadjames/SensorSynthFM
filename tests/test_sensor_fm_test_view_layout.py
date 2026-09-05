#!/usr/bin/env python3
"""Focused source-layout regression check for the modulation route editor."""

from pathlib import Path
import re
import unittest


SOURCE_PATH = (
    Path(__file__).resolve().parents[1]
    / "SensorSynthFM"
    / "SensorFMTestView.swift"
)


def property_body(source: str, name: str) -> str:
    marker = f"private var {name}: some View {{"
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    raise AssertionError(f"Unclosed computed property: {name}")


class SensorFMTestViewLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE_PATH.read_text(encoding="utf-8")

    def test_landscape_editor_is_below_matrix_without_fixed_side_inspector(self) -> None:
        landscape = re.sub(
            r"\s+", " ", property_body(self.source, "landscapeModulationSurface")
        )
        matrix = re.sub(r"\s+", " ", property_body(self.source, "matrixColumn"))

        self.assertNotIn("routeInspectorColumn", landscape)
        self.assertNotIn("private var routeInspectorColumn: some View", self.source)
        self.assertNotIn('sectionHeader("ROUTE INSPECTOR")', self.source)
        self.assertIn(
            "if isLeftHanded { matrixColumn verticalDivider contextColumn } "
            "else { contextColumn verticalDivider matrixColumn }",
            landscape,
        )
        self.assertRegex(
            matrix,
            r"modulationMatrixPanel \.padding\(12\) selectedCellEditor ",
        )
        self.assertIn(".frame(maxWidth: .infinity)", matrix)

    def test_portrait_keeps_editor_fixed_above_scroll_region(self) -> None:
        portrait = property_body(self.source, "portraitModulationSurface")

        self.assertEqual(portrait.count("selectedCellEditor"), 1)
        self.assertLess(portrait.index("selectedCellEditor"), portrait.index("ScrollView"))

    def test_active_route_exposes_visible_removal_control(self) -> None:
        editor = re.sub(r"\s+", " ", property_body(self.source, "selectedCellEditor"))

        self.assertIn('Label("REMOVE ROUTE", systemImage: "trash")', editor)
        self.assertIn('private func clearSelectedRoute()', self.source)
        self.assertRegex(editor, r'Label\("REMOVE ROUTE", systemImage: "trash"\).*frame\(maxWidth: \.infinity, minHeight: 44\)')
        self.assertNotIn('if !ModulationAmountInteraction.isZero(amount)', editor)
        self.assertIn('.opacity(ModulationAmountInteraction.isZero(amount) ? 0 : 1)', editor)
        self.assertIn('.allowsHitTesting(!ModulationAmountInteraction.isZero(amount))', editor)
        self.assertIn('.disabled(ModulationAmountInteraction.isZero(amount))', editor)

        cell = re.sub(r"\s+", " ", self.source[self.source.index("private func matrixCell"):self.source.index("private var selectedCellEditor")])
        self.assertIn(".onTapGesture(count: 2)", cell)
        self.assertIn("guard active else { return }", cell)

    def test_selected_zero_route_explains_activation_without_color(self) -> None:
        cell = re.sub(r"\s+", " ", self.source[self.source.index("private func matrixCell"):self.source.index("private var selectedCellEditor")])

        self.assertIn('Text("SELECTED · NEUTRAL")', cell)
        self.assertIn('Text("ADJUST TO ACTIVATE")', cell)
        self.assertIn('Selected but neutral. Adjust amount to activate this route', cell)

    def test_current_grid_uses_56_point_cells_with_scroll_fallback_and_labels(self) -> None:
        cell = re.sub(r"\s+", " ", self.source[self.source.index("private func matrixCell"):self.source.index("private var selectedCellEditor")])
        matrix = re.sub(r"\s+", " ", property_body(self.source, "modulationMatrixPanel"))

        self.assertRegex(cell, r"frame\(width: (?:5[6-9]|[6-9][0-9]|[1-9][0-9]{2,}), height: (?:5[6-9]|[6-9][0-9]|[1-9][0-9]{2,})\)")
        self.assertIn("ForEach(SensorModulationSource.allCases)", matrix)
        self.assertIn("ForEach(SensorModulationTarget.allCases)", matrix)
        self.assertIn("sourceHeader(source)", matrix)
        self.assertIn("targetLabel(target)", matrix)
        self.assertIn("ScrollView(.horizontal", matrix)
        self.assertIn("ScrollView(.vertical", matrix)

    def test_matrix_context_and_route_controls_have_stable_identifiers(self) -> None:
        source_header = re.sub(r"\s+", " ", self.source[self.source.index("private func sourceHeader"):self.source.index("private func targetLabel")])
        target_label = re.sub(r"\s+", " ", self.source[self.source.index("private func targetLabel"):self.source.index("private func matrixCell")])
        cell = re.sub(r"\s+", " ", self.source[self.source.index("private func matrixCell"):self.source.index("private var selectedCellEditor")])
        editor = re.sub(r"\s+", " ", property_body(self.source, "selectedCellEditor"))

        self.assertIn('modulation.source.\\(source.rawValue)', source_header)
        self.assertIn('modulation.target.\\(target.rawValue)', target_label)
        self.assertIn('modulation.cell.source.\\(source.rawValue).target.\\(target.rawValue)', cell)
        self.assertIn('modulation.route.remove', editor)
        self.assertIn('modulation.amount.increase', self.source)
        self.assertIn('modulation.amount.decrease', self.source)
        self.assertIn('.accessibilityElement(children: .contain)', editor)
        amount_control = re.sub(
            r"\s+",
            " ",
            self.source[
                self.source.index("private struct BipolarAmountControl") :
                self.source.index("private struct SensorBar")
            ],
        )
        self.assertIn('.accessibilityIdentifier("modulation.amount.slider")', amount_control)

    def test_ui_tests_cover_rendered_route_lifecycle_and_offscreen_scroll(self) -> None:
        ui_test = (
            SOURCE_PATH.parents[0]
            / ".."
            / "SensorSynthFMUITests"
            / "SensorSynthFMUITests.swift"
        ).resolve().read_text(encoding="utf-8")

        self.assertIn('app.launchArguments = ["-ui-testing"]', ui_test)
        self.assertIn('modulation.cell.source.3.target.0', ui_test)
        self.assertIn('SELECTED · NEUTRAL', ui_test)
        self.assertIn('modulation.amount.increase', ui_test)
        self.assertIn('modulation.route.remove', ui_test)
        self.assertIn('modulation.cell.source.8.target.0', ui_test)
        self.assertIn('modulation.matrix.viewport', ui_test)
        self.assertIn('modulation.target.0', ui_test)
        self.assertIn('modulation.selected.route.context', ui_test)

    def test_selected_route_cluster_exposes_live_source_and_state(self) -> None:
        editor = re.sub(r"\s+", " ", property_body(self.source, "selectedCellEditor"))

        self.assertIn('Text("LIVE SOURCE")', editor)
        self.assertIn("bridge.sourceValue(for: selectedSource)", editor)
        self.assertIn("SensorBar(value: bridge.sourceValue(for: selectedSource)", editor)
        self.assertIn('Text("STATE \\(stateText)")', editor)
        self.assertIn("BASE \\(format(selectedTarget", editor)
        self.assertIn("LIVE \\(format(selectedTarget", editor)

    def test_landscape_editor_has_bottom_gesture_separation(self) -> None:
        matrix = re.sub(r"\s+", " ", property_body(self.source, "matrixColumn"))

        self.assertIn("selectedCellEditor .padding(.horizontal, 12) .padding(.bottom, 24) .safeAreaPadding(.bottom, 16)", matrix)

    def test_route_editor_amount_button_resets_and_nudges_are_mirrored(self) -> None:
        editor = re.sub(r"\s+", " ", property_body(self.source, "selectedCellEditor"))

        handed_start = editor.index("if isLeftHanded")
        right_start = editor.index("} else {", handed_start)
        left_cluster = editor[handed_start:right_start]
        right_cluster = editor[right_start:]

        self.assertLess(left_cluster.index('editorButton("+")'), left_cluster.index('editorButton("−")'))
        self.assertLess(right_cluster.index('editorButton("−")'), right_cluster.index('editorButton("+")'))
        self.assertNotIn('editorButton("ZERO"', editor)
        self.assertNotIn("fullWidth", self.source)
        self.assertNotIn('title == "ZERO"', self.source)
        self.assertRegex(
            editor,
            r"Button \{ bridge\.setAmount\(0, source: selectedSource, target: selectedTarget\) "
            r"\} label: \{ Text\(amountText\).*\.frame\(minWidth: 44, minHeight: 44\).*"
            r"\.accessibilityLabel\(\"Reset selected modulation route to zero\"\).*"
            r"\.accessibilityHint\(\"Sets the selected route amount to zero\"\)",
        )


if __name__ == "__main__":
    unittest.main()
