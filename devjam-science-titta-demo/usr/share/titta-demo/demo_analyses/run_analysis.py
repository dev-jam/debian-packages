# -*- coding: utf-8 -*-
"""
Run all data processing and analysis steps of demo_analyses in one go, in the
order of the README, with the videos last:

1. extract_trial_data.py      data/*.h5        -> trials/
2. compute_data_quality.py    data/, trials/   -> data_quality/
3. detect_fixations.py        trials/          -> output/allfixations.txt
4. map fixations to AOIs      output/, AOI_example/AOIs/ -> aoi/
5. plot_scanpath.py           output/, stimuli/ -> scanpaths/
6. plot_heatmap.py            output/, stimuli/ -> heatmaps/
7. plot_heatmap_video.py      trials/, output/, stimuli/ -> heatmap_videos/
8. plot_gaze_video.py         trials/, output/, stimuli/ -> video_gaze/

Every step runs as a separate Python process from this folder, exactly as if
the script was started by hand. Settings of each step (screen size, sampling
frequency, AOI options, ...) stay in the step's own script.

Run from this folder:  python run_analysis.py
"""

import datetime
import importlib.util
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Steps to run (True) or skip (False). The order of the steps is set by
# STEPS below, not by this dict.
RUN_STEPS = {
    'extract_trials': True,
    'data_quality': True,
    'detect_fixations': True,
    'map_aois': True,
    'scanpaths': True,
    'heatmaps': True,
    'heatmap_video': True,      # one video per stimulus, all participants
    'gaze_video': True,         # slow: one frame per sample
}

# Stop at the first step that fails (True), or continue with the next steps
STOP_ON_ERROR = True

# Settings for step 4 (map fixations to AOIs). The fixations come from
# detect_fixations.py (output/allfixations.txt); all output goes to AOI_OUTPUT.
AOI_SCRIPT = Path('AOI_example') / 'map_fixations_to_aois.py'
AOI_FOLDER = Path('AOI_example') / 'AOIs'
AOI_OUTPUT = Path('aoi')

FIXATION_FILE = Path('output') / 'allfixations.txt'

HERE = Path(__file__).resolve().parent


def missing_modules(modules):
    """Return the modules (import names) that are not installed."""
    return [m for m in modules if importlib.util.find_spec(m) is None]


def run_script(script, extra_code=None):
    """Run a script (or extra_code) in a new Python process from HERE."""
    if extra_code is None:
        cmd = [sys.executable, str(script)]
    else:
        cmd = [sys.executable, '-c', extra_code]
    return subprocess.run(cmd, cwd=HERE).returncode


def backup_fixation_file():
    """Move an existing allfixations.txt to output/previous/.

    detect_fixations.py does not overwrite allfixations.txt but writes to
    allfixations_1.txt etc., so the later steps would read the old fixations.
    """
    fix_file = HERE / FIXATION_FILE
    if fix_file.exists():
        stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        backup = fix_file.parent / 'previous' / f'allfixations_{stamp}.txt'
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(fix_file), str(backup))
        print(f'Existing {FIXATION_FILE} moved to {backup.relative_to(HERE)}')


def aoi_code():
    """Python code that runs map_fixations_to_aois.main() on output/allfixations.txt."""
    output = AOI_OUTPUT.as_posix()
    return (
        'import sys\n'
        f'sys.path.insert(0, {str((HERE / AOI_SCRIPT).parent)!r})\n'
        'import map_fixations_to_aois as m\n'
        f'm.FIXATION_FILE = {FIXATION_FILE.as_posix()!r}\n'
        f'm.AOI_FOLDER = {AOI_FOLDER.as_posix()!r}\n'
        f"m.OUTPUT_FILE = '{output}/fixation_aoi_hits.csv'\n"
        f"m.FIRST_FIXATION_FILE = '{output}/aoi_first_fixation.csv'\n"
        f"m.CUMULATIVE_FOLDER = '{output}/cumulative_plots'\n"
        "if __name__ == '__main__':\n"
        '    m.main()\n'
    )


def check_aoi_step():
    """Return a reason to skip the AOI step, or None."""
    script = HERE / AOI_SCRIPT
    if not script.exists():
        return f'{AOI_SCRIPT} not found'
    # The old version of the script has no main() and runs on import
    if 'def main(' not in script.read_text(encoding='utf-8'):
        return f'{AOI_SCRIPT} is the old version without main()'
    if not (HERE / AOI_FOLDER).is_dir():
        return f'AOI folder {AOI_FOLDER} not found'
    return None


# Steps in the order they run: name, script, required modules (import
# names), input that must exist
STEPS = [
    ('extract_trials', 'extract_trial_data.py', ['pandas', 'h5py', 'tables'], 'data'),
    ('data_quality', 'compute_data_quality.py', ['pandas', 'tables'], 'trials'),
    ('detect_fixations', 'detect_fixations.py', ['I2MC', 'pandas'], 'trials'),
    ('map_aois', str(AOI_SCRIPT), ['numpy', 'pandas', 'PIL', 'matplotlib'],
     str(FIXATION_FILE)),
    ('scanpaths', 'plot_scanpath.py', ['pandas', 'cv2'], str(FIXATION_FILE)),
    ('heatmaps', 'plot_heatmap.py', ['numpy', 'pandas', 'PIL', 'matplotlib'],
     str(FIXATION_FILE)),
    ('heatmap_video', 'plot_heatmap_video.py',
     ['numpy', 'pandas', 'PIL', 'matplotlib', 'cv2'], str(FIXATION_FILE)),
    # Last, because it is by far the slowest step
    ('gaze_video', 'plot_gaze_video.py', ['pandas', 'cv2'], str(FIXATION_FILE)),
]


def main():
    start_time = time.perf_counter()
    results = []

    for i, (name, script, modules, needed_input) in enumerate(STEPS, start=1):
        header = f'[{i}/{len(STEPS)}] {name} ({script})'
        print(f'\n{"=" * 70}\n{header}\n{"=" * 70}')

        if not RUN_STEPS.get(name, False):
            print('Skipped (RUN_STEPS)')
            results.append((name, 'skipped', 0.0))
            continue

        # A script that is not available (yet) is skipped, not an error
        skip = None
        if not (HERE / script).exists():
            skip = f'{script} not found'
        elif name == 'map_aois':
            skip = check_aoi_step()
        if skip is not None:
            print(f'Skipped: {skip}')
            results.append((name, 'skipped: ' + skip, 0.0))
            continue

        reason = None
        if missing_modules(modules):
            # plot_scanpath.py falls back to PsychoPy if OpenCV is missing
            if not (name == 'scanpaths' and not missing_modules(['psychopy'])):
                reason = 'missing Python packages: ' + ', '.join(missing_modules(modules))
        if reason is None and needed_input and name != 'detect_fixations' \
                and not (HERE / needed_input).exists():
            reason = f'input {needed_input} not found (run the earlier steps first)'

        if reason is not None:
            print(f'Not run: {reason}')
            results.append((name, 'not run: ' + reason, 0.0))
            if STOP_ON_ERROR:
                break
            continue

        if name == 'detect_fixations':
            backup_fixation_file()
        if name == 'map_aois':
            (HERE / AOI_OUTPUT).mkdir(parents=True, exist_ok=True)

        t0 = time.perf_counter()
        code = aoi_code() if name == 'map_aois' else None
        returncode = run_script(HERE / script, code)
        elapsed = time.perf_counter() - t0

        if returncode == 0:
            results.append((name, 'ok', elapsed))
        else:
            results.append((name, f'failed (exit code {returncode})', elapsed))
            print(f'\nStep {name} failed with exit code {returncode}')
            if STOP_ON_ERROR:
                break

    print(f'\n{"=" * 70}\nSummary\n{"=" * 70}')
    for name, status, elapsed in results:
        print(f'{name:<18} {elapsed:7.1f} s  {status}')
    for name, *_ in STEPS[len(results):]:
        print(f'{name:<18} {"":>9}  not reached')

    total = time.perf_counter() - start_time
    minutes, seconds = divmod(total, 60)
    print(f'Total time: {int(minutes)} min {seconds:.1f} s')

    failed = any(not status.startswith(('ok', 'skipped')) for _, status, _ in results)
    sys.exit(1 if failed or len(results) < len(STEPS) else 0)


if __name__ == '__main__':
    main()
