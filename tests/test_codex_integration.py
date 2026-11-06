from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import install_codex  # noqa: E402
import sync_codex_skills  # noqa: E402


class CodexIntegrationTests(unittest.TestCase):
    def test_generated_skills_have_valid_metadata_and_canonical_sources(self) -> None:
        source_names = set()
        for source in sorted((ROOT / "skills").glob("*/SKILL.md")):
            name, description = sync_codex_skills.parse_source_skill(source)
            source_names.add(name)
            self.assertTrue(description.strip(), source)
            destination = ROOT / ".agents" / "skills" / name / "SKILL.md"
            self.assertTrue(destination.is_file(), destination)
            content = destination.read_text(encoding="utf-8")
            self.assertIn(sync_codex_skills.GENERATED_MARKER, content)
            self.assertIn("CC BY 4.0", content)
            self.assertIn("https://creativecommons.org/licenses/by/4.0/", content)
            frontmatter = re.search(r"(?ms)^---\s*\n(.*?)\n---\s*\n", content)
            self.assertIsNotNone(frontmatter, destination)
            fields = frontmatter.group(1).splitlines()
            self.assertIn(f"name: {name}", fields)
            description_line = next(line for line in fields if line.startswith("description: "))
            parsed_description = json.loads(description_line.removeprefix("description: "))
            self.assertEqual(parsed_description, description)
            source_reference = sync_codex_skills.COMMAND_WORKFLOWS.get(name, f"skills/{name}/SKILL.md")
            self.assertIn(f"<vault_root>/{source_reference}", content)

        generated = list((ROOT / ".agents" / "skills").glob("*/SKILL.md"))
        self.assertEqual(len(generated), len(source_names) + len(sync_codex_skills.EXTRA_SKILLS))
        self.assertTrue((ROOT / ".agents/skills/lihfolk-vault-search/scripts/vault_search.py").is_file())

    def test_installer_is_idempotent_and_merges_project_configuration(self) -> None:
        with tempfile.TemporaryDirectory(prefix="LihFolk Codex project ") as temp:
            project = Path(temp) / "Roblox game with spaces"
            project.mkdir()
            (project / ".git").mkdir()
            (project / "AGENTS.md").write_text("# Existing project instructions\nKeep this line.\n", encoding="utf-8")
            (project / ".gitignore").write_text("node_modules/\n", encoding="utf-8")
            codex_dir = project / ".codex"
            codex_dir.mkdir()
            (codex_dir / "config.toml").write_text(
                "[features]\nresponses_websockets = true\ncodex_hooks = false\n\n[other]\nanswer = 42\n",
                encoding="utf-8",
            )
            existing_hooks = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "keep-me"}]}]}, "custom": True}
            (codex_dir / "hooks.json").write_text(json.dumps(existing_hooks), encoding="utf-8")

            self.run_installer(project, ROOT, enable_hooks=True)
            first_agents = (project / "AGENTS.md").read_text(encoding="utf-8")
            first_config = (codex_dir / "config.toml").read_text(encoding="utf-8")
            self.run_installer(project, ROOT, enable_hooks=True)

            self.assertEqual((project / "AGENTS.md").read_text(encoding="utf-8"), first_agents)
            self.assertEqual((codex_dir / "config.toml").read_text(encoding="utf-8"), first_config)
            self.assertIn("Keep this line.", first_agents)
            self.assertEqual(first_agents.count(install_codex.AGENTS_START), 1)
            self.assertIn("node_modules/", (project / ".gitignore").read_text(encoding="utf-8"))
            self.assertIn(".lihfolk-codex.json", (project / ".gitignore").read_text(encoding="utf-8"))
            local_config = json.loads((project / ".lihfolk-codex.json").read_text(encoding="utf-8"))
            self.assertEqual(local_config["vault_root"], str(ROOT))
            self.assertEqual(local_config["python_executable"], str(Path(sys.executable).resolve()))
            self.assertEqual(len(list((project / ".agents/skills").glob("*/SKILL.md"))), 24)
            self.assertTrue((project / ".codex/agents/lihfolk_lookup.toml").is_file())
            self.assertIn("CC BY 4.0", (project / ".codex/agents/lihfolk_lookup.toml").read_text(encoding="utf-8"))
            self.assertTrue((project / ".codex/lihfolk/codex_post_tool.py").is_file())
            self.assertIn("CC BY 4.0", (project / ".codex/lihfolk/codex_post_tool.py").read_text(encoding="utf-8"))

            hooks = json.loads((codex_dir / "hooks.json").read_text(encoding="utf-8"))
            self.assertTrue(hooks["custom"])
            self.assertEqual(hooks["hooks"]["Stop"][0]["hooks"][0]["command"], "keep-me")
            self.assertEqual(len(hooks["hooks"]["PostToolUse"]), 1)
            self.assertIn("CC BY 4.0", hooks["description"])
            with (codex_dir / "config.toml").open("rb") as stream:
                import tomllib

                config = tomllib.load(stream)
            self.assertTrue(config["features"]["responses_websockets"])
            self.assertTrue(config["features"]["codex_hooks"])
            self.assertEqual(config["other"]["answer"], 42)

    def test_installer_refuses_unmanaged_skill_conflict_before_writing(self) -> None:
        with tempfile.TemporaryDirectory(prefix="LihFolk Codex conflict ") as temp:
            project = Path(temp)
            conflict = project / ".agents/skills/lihfolk/SKILL.md"
            conflict.parent.mkdir(parents=True)
            conflict.write_text("# User-owned skill\n", encoding="utf-8")

            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts/install_codex.py"), "--project", str(project), "--vault-root", str(ROOT)],
                cwd=project,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("Refusing to overwrite", result.stderr)
            self.assertEqual(conflict.read_text(encoding="utf-8"), "# User-owned skill\n")
            self.assertFalse((project / ".lihfolk-codex.json").exists())
            self.assertFalse((project / "AGENTS.md").exists())

    def test_vault_helper_forwards_argument_vectors_from_paths_with_spaces(self) -> None:
        with tempfile.TemporaryDirectory(prefix="LihFolk vault root ") as vault_temp, tempfile.TemporaryDirectory(prefix="LihFolk game project ") as project_temp:
            vault = Path(vault_temp)
            fake_tool = vault / "LihFolk Vault V2/_tools/vault.py"
            fake_tool.parent.mkdir(parents=True)
            fake_tool.write_text(
                "import json, sys\nprint(json.dumps(sys.argv[1:]))\n",
                encoding="utf-8",
            )
            project = Path(project_temp)
            self.run_installer(project, vault)
            helper = project / ".agents/skills/lihfolk-vault-search/scripts/vault_search.py"
            query = "remote validation with spaces; harmless text"
            result = subprocess.run(
                [sys.executable, str(helper), query],
                cwd=project,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), [query])

    def test_post_tool_hook_reports_errors_and_soft_warnings(self) -> None:
        with tempfile.TemporaryDirectory(prefix="LihFolk Roblox project ") as temp:
            project = Path(temp)
            (project / ".git").mkdir()
            self.run_installer(project, ROOT, enable_hooks=True)
            data_file = project / "ServerScriptService/DataStore.luau"
            data_file.parent.mkdir(parents=True)
            data_file.write_text(
                "local DataStoreService = game:GetService(\"DataStoreService\")\n"
                "local Store = DataStoreService:GetDataStore(\"PlayerData\")\n"
                "local data = Store:GetAsync(\"player_1\")\n",
                encoding="utf-8",
            )
            patch_event = {
                "hook_event_name": "PostToolUse",
                "tool_name": "apply_patch",
                "cwd": str(project),
                "tool_input": {"command": f"*** Begin Patch\n*** Update File: {data_file.relative_to(project).as_posix()}\n"},
            }
            hook_script = project / ".codex/lihfolk/codex_post_tool.py"
            result = subprocess.run(
                [sys.executable, str(hook_script)],
                cwd=project,
                input=json.dumps(patch_event),
                text=True,
                capture_output=True,
                check=False,
                timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            response = json.loads(result.stdout)
            self.assertEqual(response["decision"], "block")
            self.assertIn("datastore-no-pcall", response["reason"])
            self.assertIn("datastore-no-pcall", response["hookSpecificOutput"]["additionalContext"])

            warning_file = project / "ServerScriptService/Deprecated.luau"
            warning_file.write_text("task.wait(0)\nwait(1)\n", encoding="utf-8")
            warning_event = {
                **patch_event,
                "tool_input": {"command": f"*** Begin Patch\n*** Add File: {warning_file.relative_to(project).as_posix()}\n"},
            }
            warning_result = subprocess.run(
                [sys.executable, str(hook_script)],
                cwd=project,
                input=json.dumps(warning_event),
                text=True,
                capture_output=True,
                check=False,
                timeout=30,
            )
            self.assertEqual(warning_result.returncode, 0, warning_result.stderr)
            warning_response = json.loads(warning_result.stdout)
            self.assertNotIn("decision", warning_response)
            self.assertIn("deprecated-wait", warning_response["hookSpecificOutput"]["additionalContext"])

    @staticmethod
    def run_installer(project: Path, vault: Path, enable_hooks: bool = False) -> None:
        command = [
            sys.executable,
            str(ROOT / "scripts/install_codex.py"),
            "--project",
            str(project),
            "--vault-root",
            str(vault),
        ]
        if enable_hooks:
            command.append("--enable-hooks")
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False, timeout=30)
        if result.returncode != 0:
            raise AssertionError(f"Installer failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")


if __name__ == "__main__":
    unittest.main()
