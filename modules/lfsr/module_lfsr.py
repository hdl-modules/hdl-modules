# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import re
from pathlib import Path
from typing import TYPE_CHECKING, Any

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.system_utils import read_file
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts
from tsfpga.vivado.generics import BitVectorGenericValue

if TYPE_CHECKING:
    # Third party libraries
    from numpy import ndarray


class Module(BaseModule):
    def setup_vunit(  # pylint: unused-argument
        self, vunit_proj: Any, inspect: bool = False, **kwargs: Any
    ) -> None:
        self._setup_lfsr_pkg_tests(vunit_proj=vunit_proj)
        self._setup_lfsr_tests(vunit_proj=vunit_proj, inspect=inspect)

    def _setup_lfsr_pkg_tests(self, vunit_proj: Any) -> None:
        def post_check(output_path: str) -> bool:  # pylint: disable=unused-argument
            return self.post_check_lfsr_pkg()

        tb = vunit_proj.library(self.library_name).test_bench("tb_lfsr_pkg")
        self.add_vunit_config(test=tb, post_check=post_check)

    def _setup_lfsr_tests(self, vunit_proj: Any, inspect: bool) -> None:
        def get_post_check(generics: dict[str, Any]):
            return lambda output_path: self.post_check_lfsr(
                output_path=Path(output_path), generics=generics, inspect=inspect
            )

        tb = vunit_proj.library(self.library_name).test_bench("tb_lfsr")
        # Can simulate all the way up to 31 bits, but simulation time gets quite long.
        for width in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]:
            for output_width in [1, width]:
                # When in single-output-bit mode, the LFSR is exactly this.
                # When in non-single-output-bit mode, the LFSR is at least this.
                desired_lfsr_length = width

                generics = dict(output_width=output_width, desired_lfsr_length=desired_lfsr_length)

                self.add_vunit_config(
                    test=tb,
                    generics=generics,
                    set_random_seed=True,
                    post_check=get_post_check(generics=generics),
                )

    def post_check_lfsr_pkg(self) -> bool:
        """
        Sanity check the LFSR package VHDL file.
        According to the necessary but not sufficient criteria for a maximal-length LFSR listed on
        Wikipedia: https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Fibonacci_LFSRs
        """
        # Standard libraries
        # pylint: disable=import-outside-toplevel
        from math import gcd

        vhd = read_file(self.path / "src" / "lfsr_pkg.vhd")

        matches = re.findall(r"(\d+) => \((\d+), ([\d-]+), ([\d-]+), ([\d-]+), ([\d-]+)\)", vhd)

        # 2 through 64 => 63 entries.
        assert len(matches) == 63, f"Unexpected number of entries in the LFSR table: {matches}"

        for match in matches:
            match_numbers = [int(number) for number in match]
            taps = []

            for number in match_numbers:
                if number != 0:
                    taps.append(number)

            assert len(taps) > 1, f"Unreasonable number of non-zero taps {taps}"
            assert len(taps) % 2 == 0, f"Unreasonable number of non-zero taps {taps}"
            assert gcd(*taps) == 1, f"taps should be set-wise co-prime {taps}"

        return True

    def post_check_lfsr(  # pylint: disable=too-many-locals
        self, output_path: Path, generics: dict[str, Any], inspect: bool
    ) -> None:
        """
        Check that the output spectrum has only a DC component and a flat noise floor.
        This is not in itself a particularly strong test for randomness.
        However, we are not trying to prove that maximum-length LFSRs are random,
        we are trying to prove that our implementation indeed implements a maximum-length LFSR.
        Which this spectrum test does quite well.
        Changing one of the taps to something incorrect makes the test fail spectacularly.
        """
        # pylint: disable=import-outside-toplevel
        # Standard libraries
        from math import log2

        # Third party libraries
        from numpy import abs as np_abs
        from numpy import log10, mean, std, var
        from scipy.fft import rfft

        signal = self.load_simulation_data(output_path=output_path)

        # https://docs.scipy.org/doc/scipy/reference/generated/scipy.fft.rfft.html
        power_spectrum_db = 20 * log10(np_abs(rfft(signal)))
        power_spectrum_db_normalized = power_spectrum_db - max(power_spectrum_db)

        noise_floor_db = self.get_noise_floor_db(power_spectrum_db=power_spectrum_db_normalized)
        noise_floor_enob = self.calculate_enob(value_db=noise_floor_db)

        average = mean(signal)
        variance = var(signal)
        standard_deviation = std(signal)
        standard_deviation_percent = standard_deviation / average * 100

        lfsr_length = log2(signal.size + 1)

        kpi_text = f"""\
LFSR length: {lfsr_length}
Num samples: {signal.size}

Mean: {average:.2f}
Variance: {variance:.2f}
Standard deviation: {standard_deviation:.2f} ({standard_deviation_percent:.2f}%)

Noise floor (dB): {noise_floor_db:.2f}
Noise floor (ENOB): {noise_floor_enob:.2f}\
"""
        print(kpi_text)

        if inspect:
            self.plot(
                signal=signal,
                power_spectrum_db=power_spectrum_db_normalized,
                noise_floor_db=noise_floor_db,
                kpi_text=kpi_text,
            )

        expected_enob = generics["desired_lfsr_length"] / 2
        lower_limit_enob = expected_enob - 0.3
        # When using multi-bit output, the internal LFSR length is almost always greater than
        # the output width, which yields a slightly lower noise floor.
        upper_limit_enob = expected_enob + 0.6 + 2 * (generics["output_width"] > 1)
        assert (
            lower_limit_enob < noise_floor_enob < upper_limit_enob
        ), f"Unexpected ENOB. Got {noise_floor_enob}, expected at circa {expected_enob}."

        return True

    def load_simulation_data(self, output_path: Path) -> "ndarray":
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from numpy import float64, fromfile, int32

        file_path = output_path / "simulation_data.raw"
        # Samples are saved as integers in the testbench.
        data = fromfile(file=file_path, dtype=int32)

        # Convert to floating point so we can process the data.
        return data.astype(float64)

    @staticmethod
    def plot(
        signal: "ndarray", power_spectrum_db: "ndarray", noise_floor_db: float, kpi_text: str
    ) -> None:
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from matplotlib import pyplot as plt
        from numpy import arange

        fig = plt.figure(figsize=(15, 7))
        (ax_signal, ax_spectrum) = fig.subplots(1, 2)

        line_style = "o-" if signal.size < 20_000 else "-"

        ax_signal.set_title("Signal")
        ax_signal.plot(arange(signal.size), signal, line_style, color="tab:orange")
        ax_signal.set_xlim([0, signal.size - 1])

        ax_spectrum.set_title("Power spectrum (dB)")
        ax_spectrum.plot(
            arange(power_spectrum_db.size), power_spectrum_db, line_style, color="tab:blue"
        )
        ax_spectrum.set_xlim([0, power_spectrum_db.size - 1])

        ax_spectrum.axhline(y=-noise_floor_db, color="tab:red", linestyle="--")
        ax_spectrum.text(x=power_spectrum_db.size // 3, y=-0.5 * noise_floor_db, s=kpi_text)

        plt.show()

    @staticmethod
    def get_noise_floor_db(power_spectrum_db: "ndarray") -> float:
        """
        If the data is random, the power spectrum should be a peak DC component, and otherwise
        a somewhat flat noise floor.
        Based on this assumption, the computation becomes quite trivial.
        """
        return -power_spectrum_db[1:].max()

    @staticmethod
    def calculate_enob(value_db: float) -> float:
        """
        Calculate how many bits of digital quantization noise the given dB value equates.
        https://en.wikipedia.org/wiki/Effective_number_of_bits
        """
        return (value_db - 1.76) / 6.02

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common"])
        part = "xc7z020clg400-1"

        generics = dict(lfsr_length=52)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.lfsr_fibonacci_single", generics),
                modules=modules,
                part=part,
                top="lfsr_fibonacci_single",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(4)),
                    Ffs(EqualTo(2)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        generics = dict(lfsr_length=15)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.lfsr_fibonacci_single", generics),
                modules=modules,
                part=part,
                top="lfsr_fibonacci_single",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(2)),
                    Ffs(EqualTo(2)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        # Setting a non-default seed should not affect resource usage.
        generics.update(seed=BitVectorGenericValue("010101010101010"))
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.lfsr_fibonacci_single", generics),
                modules=modules,
                part=part,
                top="lfsr_fibonacci_single",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(2)),
                    Ffs(EqualTo(2)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        # When we read the whole state as output, the shift register can not be implemented as SRL.
        # Instead, FF usage goes up.
        # This one gets implemented as a 13-bit LFSR.
        generics = dict(output_width=12)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.lfsr_fibonacci_multi", generics),
                modules=modules,
                part=part,
                top="lfsr_fibonacci_multi",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(8)),
                    Ffs(EqualTo(13)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        # This one gets implemented as a 19-bit LFSR.
        generics = dict(output_width=16)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.lfsr_fibonacci_multi", generics),
                modules=modules,
                part=part,
                top="lfsr_fibonacci_multi",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(10)),
                    Ffs(EqualTo(19)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        return projects
