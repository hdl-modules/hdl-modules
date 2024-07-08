# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from pathlib import Path
from typing import TYPE_CHECKING, Any, Callable, Optional, Union

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import (
    DspBlocks,
    EqualTo,
    Ffs,
    MaximumLogicLevel,
    Ramb18,
    Ramb36,
    TotalLuts,
)

if TYPE_CHECKING:
    # Third party libraries
    from matplotlib.axes import Axes
    from numpy import ndarray


# pylint: disable=too-many-lines


class Module(BaseModule):
    def setup_vunit(  # pylint: disable=arguments-differ, unused-argument
        self, vunit_proj: Any, inspect: bool, **kwargs: Any
    ) -> None:
        self._setup_lookup_tests(vunit_proj=vunit_proj, inspect=inspect)
        self._setup_generator_tests(vunit_proj=vunit_proj, inspect=inspect)

    def _setup_lookup_tests(self, vunit_proj: Any, inspect: bool) -> None:
        def get_post_check(generics: dict[str, Any]) -> Callable:
            def post_check(output_path: str) -> bool:
                return self.lookup_post_check(
                    output_path=Path(output_path), generics=generics, inspect=inspect
                )

            return post_check

        tb = vunit_proj.library(self.library_name).test_bench("tb_sine_lookup")
        for memory_address_width in [7, 12]:
            for memory_data_width in [8, 18]:
                generics = dict(
                    memory_address_width=memory_address_width, memory_data_width=memory_data_width
                )
                self.add_vunit_config(
                    test=tb, generics=generics, post_check=get_post_check(generics=generics)
                )

    def _setup_generator_tests(  # pylint: disable=too-many-statements
        self, vunit_proj: Any, inspect: bool
    ) -> None:
        # Standard libraries
        # pylint: disable=import-outside-toplevel
        from dataclasses import dataclass

        tb = vunit_proj.library(self.library_name).test_bench("tb_sine_generator")

        # Set clock frequency to a power-of-two, to maximize chance of getting nice numbers.
        # Does not matter for the implementation.
        clk_frequency_hz = 2**27

        @dataclass
        class Config:
            integer_increment: str
            fractional_increment: Optional[str] = None
            enable_sine: Optional[bool] = None
            enable_cosine: Optional[bool] = None

        def add_config(config: Config) -> None:
            integer_phase_width = len(config.integer_increment)
            phase_fractional_increment = config.fractional_increment or ""
            phase_fractional_width = len(phase_fractional_increment)
            phase_width = integer_phase_width + phase_fractional_width

            phase_increment_bin = config.integer_increment + phase_fractional_increment
            phase_increment_int = int(phase_increment_bin, base=2)

            sine_frequency_hz = clk_frequency_hz * phase_increment_int / 2**phase_width
            assert sine_frequency_hz.is_integer()
            sine_frequency_hz = int(sine_frequency_hz)

            coherent_sampling_count = get_coherent_sampling_count(
                sample_rate_hz=clk_frequency_hz, sine_frequency_hz=sine_frequency_hz
            )

            def get_post_check(generics: dict[str, Any]) -> Callable:
                def post_check(output_path: str) -> bool:
                    return self.generator_post_check(
                        output_path=Path(output_path),
                        generics=generics,
                        phase_fractional_increment=phase_fractional_increment,
                        coherent_sampling_count=coherent_sampling_count,
                        inspect=inspect,
                    )

                return post_check

            for enable_phase_dithering in [False, True]:
                for enable_first_order_taylor in [False, True]:
                    if enable_phase_dithering and enable_first_order_taylor:
                        # May not enable both.
                        continue

                    if (
                        enable_phase_dithering or enable_first_order_taylor
                    ) and phase_fractional_width == 0:
                        # Neither of these make sense if we have no fractional phase.
                        continue

                    # It is technically enough to run one coherent section, but we run two
                    # to show that there is no faulty state.
                    num_samples = 2 * coherent_sampling_count

                    generics = dict(
                        clk_frequency_hz=clk_frequency_hz,
                        sine_frequency_hz=sine_frequency_hz,
                        memory_address_width=integer_phase_width - 2,
                        enable_phase_dithering=enable_phase_dithering,
                        enable_first_order_taylor=enable_first_order_taylor,
                        num_samples=num_samples,
                    )
                    # Assign the non-default value only when used, to keep
                    # test case names mostly short, and make filtering easier.
                    if phase_fractional_width:
                        generics["phase_fractional_width"] = phase_fractional_width
                    if config.enable_sine is not None:
                        generics["enable_sine"] = config.enable_sine
                    if config.enable_cosine is not None:
                        generics["enable_cosine"] = config.enable_cosine

                    self.add_vunit_config(
                        test=tb,
                        generics=generics,
                        post_check=get_post_check(generics=generics),
                    )

        def add_sine_cosine_config(config: Config) -> None:
            """
            Test sine/cosine enabled in different configurations.
            """
            for enable_sine in [False, True]:
                for enable_cosine in [False, True]:
                    if not enable_sine and not enable_cosine:
                        continue

                    config.enable_sine = enable_sine
                    config.enable_cosine = enable_cosine
                    add_config(config=config)

        # Performance plots in documentation are made from these two test cases.
        # add_config(Config(integer_increment="000111111", fractional_increment="000000"))
        # add_config(Config(integer_increment="000111111", fractional_increment="000010"))

        # Test a few different integer phase increments.
        # Show that enabling a fractional phase but utilizing only the integer part of it
        # still gives performance as if it was an integer phase.
        add_config(Config(integer_increment="000000001"))
        add_config(Config(integer_increment="000001000", fractional_increment="0000"))
        add_config(Config(integer_increment="000010000", fractional_increment="0000"))

        # Test integer phase with a different memory depth.
        add_config(Config(integer_increment="00001"))
        add_config(Config(integer_increment="00010"))

        # Test a few different fractional phase increments.
        add_config(Config(integer_increment="000010000", fractional_increment="1000"))
        add_config(Config(integer_increment="000010000", fractional_increment="1001"))
        add_config(Config(integer_increment="000000000", fractional_increment="1000"))
        # Extreme case where dithering is very visible in the resulting waveform.
        add_config(Config(integer_increment="000000000", fractional_increment="0001"))
        # Test wider fractional phase.
        add_config(Config(integer_increment="000010000", fractional_increment="01000000"))
        add_config(Config(integer_increment="000010000", fractional_increment="000001000"))

        add_config(Config(integer_increment="01000001", fractional_increment="10000"))
        add_config(Config(integer_increment="01000001", fractional_increment="00001"))

        add_config(Config(integer_increment="01000000", fractional_increment="10000"))
        add_config(Config(integer_increment="01000000", fractional_increment="00001"))

        add_config(Config(integer_increment="00000000", fractional_increment="00001"))

        add_config(Config(integer_increment="0000000000", fractional_increment="00001"))

        add_config(Config(integer_increment="00000001", fractional_increment="00001"))

        add_config(Config(integer_increment="00000010", fractional_increment="00001"))

        # Test with different configurations of sine/cosine enabled.
        # Both fractional and integer phase.
        add_sine_cosine_config(Config(integer_increment="0001000000", fractional_increment="10000"))
        add_sine_cosine_config(Config(integer_increment="010010100"))

        # These tests are way too long to run continuously in CI.
        # They do however test the performance at the extreme end, so they need to be run when
        # doing any changes to the implementation.
        # for memory_address_width in range(9, 16):
        #     integer_increment = "0000001" + ((memory_address_width + 2 - 7) * "0")

        #     add_config(Config(integer_increment=integer_increment, fractional_increment="10000"))
        #     # Test with an extreme fractional width, which leads to a very wide error term when
        #     # doing Taylor expansion.
        #     add_config(
        #         Config(
        #             integer_increment=integer_increment,
        #             fractional_increment="1000000000000000000",
        #         )
        #     )

    def lookup_post_check(  # pylint: disable=too-many-locals
        self, output_path: Path, generics: dict[str, Any], inspect: bool
    ) -> bool:
        """
        Check the result from a sine_lookup test.
        """
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from numpy import array_equal, roll

        # Set something, does not matter.
        sample_rate_hz = 100e6

        names = ["sine", "cosine", "minus_sine", "minus_cosine"]
        signals = []
        for name in names:
            signals.append(self.load_simulation_data(output_folder=output_path, file_name=name))

        peak_frequency_hz_list = []
        sndr_db_list = []
        for idx, signal in enumerate(signals):
            frequency_axis_hz, power_spectrum = get_power_spectrum(
                signal=signal, sample_rate_hz=sample_rate_hz
            )
            peak_frequency_hz, sndr_db = calculate_single_tone_sndr(
                power_spectrum=power_spectrum, frequency_axis_hz=frequency_axis_hz
            )

            peak_frequency_hz_list.append(peak_frequency_hz)
            sndr_db_list.append(sndr_db)

            sndr_enob = calculate_enob(value_db=sndr_db)

            kpi_text = (
                f"{names[idx]} SNDR ENOB = {sndr_enob:.2f} @ "
                f"{to_engineering_notation(peak_frequency_hz)}Hz"
            )
            print(kpi_text)

        if inspect:
            # pylint: disable=import-outside-toplevel
            # Third party libraries
            from matplotlib import pyplot as plt

            fig = self.setup_plot_figure()

            ax_signal, ax_spectrum = fig.subplots(1, 2)

            colors = ["blue", "orange", "green", "red"]
            for idx, signal in enumerate(signals):
                plot_signal_on_ax(ax=ax_signal, signal=signal, color=f"tab:{colors[idx]}")

            # Plot only the spectrum from one of the signals.
            # They should be all the same, which is checked below.
            plot_power_spectrum_on_ax(
                ax=ax_spectrum,
                frequency_axis_hz=frequency_axis_hz,
                power_spectrum=power_spectrum,
                peak_frequency_hz=peak_frequency_hz,
                floor_db=sndr_db,
                peak_text=kpi_text,
            )

            plt.show()

        # Check that all the KPIs are the same.
        assert len(set(peak_frequency_hz_list)) == 1, peak_frequency_hz_list
        assert len(set(sndr_db_list)) == 1, sndr_db_list

        # Sanity check that the SNDR is reasonable.
        expected_enob = generics["memory_data_width"] + 1
        assert expected_enob * 0.99 < sndr_enob < expected_enob * 1.01, sndr_enob

        # Check that they are phase shifted exactly as expected.
        assert signal.size % 4 == 0, signal.size
        for idx, signal in enumerate(signals):
            rolled = roll(signal, idx * signal.size // 4)
            assert array_equal(rolled, signals[0]), idx

        return True

    def generator_post_check(
        self,
        output_path: Path,
        generics: dict[str, int],
        phase_fractional_increment: str,
        coherent_sampling_count: int,
        inspect: bool,
    ) -> bool:
        """
        Checking the result from a sine_generator test.
        """
        enable_sine = generics.get("enable_sine", True)
        enable_cosine = generics.get("enable_cosine", False)

        signals = []

        if enable_sine:
            sine = self.load_simulation_data(output_folder=output_path, file_name="sine")
            assert sine.shape == (generics["num_samples"],)
            signals.append(sine)

        if enable_cosine:
            cosine = self.load_simulation_data(output_folder=output_path, file_name="cosine")
            assert cosine.shape == (generics["num_samples"],)
            signals.append(cosine)

        for signal in signals:
            result = SineGeneratorResult(
                signal=signal,
                generics=generics,
                is_fractional_phase="1" in phase_fractional_increment,
            )
            print(result)

            if inspect:
                # pylint: disable=import-outside-toplevel
                # Third party libraries
                from matplotlib import pyplot as plt

                self.setup_plot_figure()

                result.plot_signal(signal=signal, coherent_sampling_count=coherent_sampling_count)
                result.plot_spectrum()

                plt.show()

            result.check()

        return True

    @staticmethod
    def load_simulation_data(output_folder: Path, file_name: str) -> "ndarray":
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from numpy import float64, fromfile, int32

        file_path = output_folder / f"{file_name}.raw"
        # Samples are saved as integers in the testbench.
        data = fromfile(file=file_path, dtype=int32)

        # Convert to floating point so we can process the data.
        return data.astype(float64)

    def setup_plot_figure(self) -> None:
        """
        Set up a suitable default matplotlib figure, with a size that looks good.
        """
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from matplotlib import pyplot as plt

        return plt.figure(figsize=(15, 7))

    def get_build_projects(self):
        # Standard libraries
        # pylint: disable=import-outside-toplevel
        from dataclasses import dataclass

        # First party libraries
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "math", "lfsr"])
        part = "xc7z020clg400-1"

        @dataclass
        class Config:  # pylint: disable=too-many-instance-attributes
            memory_width: int
            address_width: int
            luts: int
            ffs: int
            logic: int
            fractional_phase: Optional[int] = None
            sine: Optional[bool] = None
            cosine: Optional[bool] = None
            dithering: Optional[bool] = None
            taylor: Optional[bool] = None
            dsp: int = 0
            ramb18: int = 0
            ramb36: int = 0

        def add_config(config: Config) -> None:
            generics = dict(
                memory_data_width=config.memory_width, memory_address_width=config.address_width
            )
            if config.fractional_phase is not None:
                generics["phase_fractional_width"] = config.fractional_phase
            if config.sine is not None:
                generics["enable_sine"] = config.sine
            if config.cosine is not None:
                generics["enable_cosine"] = config.cosine
            if config.dithering is not None:
                generics["enable_phase_dithering"] = config.dithering
            if config.taylor is not None:
                generics["enable_first_order_taylor"] = config.taylor

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.library_name}.sine_generator", generics=generics
                    ),
                    modules=modules,
                    part=part,
                    top="sine_generator",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(config.luts)),
                        Ffs(EqualTo(config.ffs)),
                        DspBlocks(EqualTo(config.dsp)),
                        Ramb18(EqualTo(config.ramb18)),
                        Ramb36(EqualTo(config.ramb36)),
                        MaximumLogicLevel(EqualTo(config.logic)),
                    ],
                )
            )

        add_config(
            Config(memory_width=14, address_width=8, luts=39, ffs=28, dsp=0, ramb18=1, logic=7)
        )

        add_config(
            Config(memory_width=18, address_width=8, luts=45, ffs=32, dsp=0, ramb18=1, logic=8)
        )

        add_config(
            Config(memory_width=14, address_width=12, luts=47, ffs=32, dsp=0, ramb36=2, logic=7)
        )

        add_config(
            Config(
                memory_width=14,
                address_width=8,
                fractional_phase=5,
                dithering=True,
                luts=54,
                ffs=51,
                dsp=0,
                ramb18=1,
                logic=7,
            )
        )

        add_config(
            Config(
                memory_width=18,
                address_width=12,
                fractional_phase=24,
                dithering=True,
                luts=114,
                ffs=101,
                ramb36=2,
                logic=12,
            )
        )

        add_config(
            Config(
                memory_width=17,
                address_width=8,
                fractional_phase=5,
                taylor=True,
                luts=100,
                ffs=38,
                dsp=2,
                ramb18=1,
                logic=8,
            )
        )

        add_config(
            Config(
                memory_width=25,
                address_width=12,
                fractional_phase=24,
                taylor=True,
                luts=156,
                ffs=69,
                dsp=3,
                ramb36=3,
                logic=12,
            )
        )

        add_config(
            Config(
                memory_width=23,
                address_width=11,
                fractional_phase=28,
                taylor=True,
                luts=151,
                ffs=70,
                dsp=3,
                ramb18=1,
                ramb36=1,
                logic=13,
            )
        )

        # Enabling cosine instead of sine.
        # LUT count increases since more bits of the cosine are needed than the sine now,
        # and the cosine calculation in sine_lookup is more complex.
        # FF stays the same since the increase in cosine bits is compensated by the decrease in
        # sine bits.
        add_config(
            Config(
                memory_width=23,
                address_width=11,
                fractional_phase=28,
                sine=False,
                cosine=True,
                taylor=True,
                luts=161,
                ffs=70,
                dsp=3,
                ramb18=1,
                ramb36=1,
                logic=13,
            )
        )

        # Enabling both.
        # LUT count increases further since many bits of both sine and cosine are needed.
        # FF increases since full width of both sine and cosine are needed.
        add_config(
            Config(
                memory_width=23,
                address_width=11,
                fractional_phase=28,
                sine=True,
                cosine=True,
                taylor=True,
                luts=177,
                ffs=94,
                dsp=5,
                ramb18=1,
                ramb36=1,
                logic=13,
            )
        )

        return projects


def get_coherent_sampling_count(sample_rate_hz: int, sine_frequency_hz: int) -> int:
    """
    Return the number of samples needed to coherently capture the sine wave.
    Meaning, all the sine energy will be in one FFT bin and there will be no spectral leakage.
    https://www.analog.com/en/design-notes/coherent-sampling-calculator-csc.html

    Renaming N_WINDOW = N_cycles, and N_RECORD = N, where N is the number we seek.
    Note that the article approaches the problem from the other way around, i.e. with a given N.

    We want to find a solution for

        f_sine / f_sample = N_cycles / N
        <=> N = N_cycles * f_sample / f_sine
        = N_cycles * (gcd * a_sample) / (gcd * a_sine)
        = N_cycles * a_sample / a_sine,

    where N_cycles, gcd, a_sample, a_sine are positive integers.
    Minimal positive integer N, and hence fastest simulation, is given by

        N_cycles = a_sine = f_sine / gcd,

    which gives

        N = a_sample = f_sample / gcd.
    """
    # Standard libraries
    # pylint: disable=import-outside-toplevel
    from math import gcd

    greatest_common_divisor = gcd(sample_rate_hz, sine_frequency_hz)

    result_hz = sample_rate_hz / greatest_common_divisor

    assert result_hz.is_integer()
    return int(result_hz)


@staticmethod
def get_power_spectrum(
    signal: "ndarray", sample_rate_hz: Union[int, float]
) -> tuple["ndarray", "ndarray"]:
    """
    Return the power spectrum for the given time-domain signal.

    Arguments:
        signal: The time-domain data.
        sample_rate_hz: The sample rate of the data.

    Returns:
        Tuple with two elements:

        * The frequency axis that the power spectrum's bins correspond to.
        * The power spectrum with a linear scale (fft^2).
    """
    # Third party libraries
    # pylint: disable=import-outside-toplevel
    from numpy import abs as np_abs
    from scipy.fft import rfft, rfftfreq

    # https://docs.scipy.org/doc/scipy/reference/generated/scipy.fft.rfftfreq.html
    frequency_axis_hz = rfftfreq(n=len(signal), d=1.0 / sample_rate_hz)

    # https://docs.scipy.org/doc/scipy/reference/generated/scipy.fft.rfft.html
    fft = rfft(signal)
    power_spectrum = np_abs(fft) ** 2

    return frequency_axis_hz, power_spectrum


@staticmethod
def power_spectrum_to_db(power_spectrum: "ndarray") -> "ndarray":
    """
    Arguments:
        power_spectrum: A linear-scale power spectrum (fft^2).

    Returns:
        The power spectrum in a normalized dB scale (20 log10(fft)).
    """
    # Third party libraries
    # pylint: disable=import-outside-toplevel
    from numpy import log10
    from numpy import max as np_max

    power_spectrum_db = 10 * log10(power_spectrum)
    # Normalized with the peak a zero.
    power_spectrum_normalized_db = power_spectrum_db - np_max(power_spectrum_db)

    return power_spectrum_normalized_db


def calculate_single_tone_sndr(
    power_spectrum: "ndarray", frequency_axis_hz: "ndarray"
) -> tuple[float, float]:
    """
    Calculate the signal-to-(noise and distortion) ratio (SNDR) for the given power spectrum.
    The calculation is done in frequency domain.
    The calculation is highly dependent on the spectrum containing only a single sinusoid
    that is coherently sampled without spectral leakage.

    Arguments:
        power_spectrum: The linear power spectrum (fft^2) of a signal.
        frequency_axis_hz: The frequency axis that the power spectrum's bins correspond to.

    Returns:
        Tuple with two elements:

        * The frequency in Hertz of the peak in the power spectrum.
        * The SNDR in dB (20 log10(fft)).
    """
    # Third party libraries
    # pylint: disable=import-outside-toplevel
    from numpy import argmax, log10

    max_idx = argmax(power_spectrum)
    peak_frequency_hz = frequency_axis_hz[max_idx]

    peak_power = power_spectrum[max_idx]
    total_power = power_spectrum.sum()
    noise_and_distortion_power = total_power - peak_power

    sndr = peak_power / noise_and_distortion_power
    sndr_db = 10 * log10(sndr)

    return peak_frequency_hz, sndr_db


@staticmethod
def calculate_sfdr_db(power_spectrum: "ndarray") -> float:
    """
    Calculate the spurious-free dynamic range (SFDR) for the given power spectrum.
    https://en.wikipedia.org/wiki/Spurious-free_dynamic_range

    The calculation is highly dependent on the sinusoid signal being coherently sampled so there
    is no spectral leakage.

    Arguments:
        power_spectrum: The linear-scale power spectrum (fft^2).

    Returns:
        The SFDR in dB scale (20 log10(fft)).
    """
    # pylint: disable=import-outside-toplevel
    # Standard libraries
    from math import log10

    # Third party libraries
    from numpy import partition

    assert power_spectrum.size >= 1

    # https://stackoverflow.com/a/43171216
    largest_value = power_spectrum.max()
    second_largest_value = partition(power_spectrum.flatten(), -2)[-2]

    sfdr_linear_ratio = largest_value / second_largest_value
    sfdr_db = 10 * log10(sfdr_linear_ratio)

    return sfdr_db


def calculate_thd_percent(power_spectrum: "ndarray") -> float:
    """
    Calculate the total harmonic distortion (THD) for the given power spectrum.
    Result is a percentage of the total harmonic tone power to the fundamental
    tone power.

    This calculation is highly dependent on the signal containing only a single fundamental tone
    that is coherently sampled without spectral leakage.

    THD is commonly formulated as

        sqrt(V_1^2 + V_2^2 + V_3^2 + ...) / V_0,

    where V_i is the amplitude of the sinusoid signal in the time domain, and index zero
    is the fundamental tone.
    Since we have access to the power spectrum, which contains the square of the amplitudes,
    we calculate THD as

        sqrt((P_1 + P_2 + P_3 + ...) / P_0)

    https://en.wikipedia.org/wiki/Total_harmonic_distortion
    https://www.allaboutcircuits.com/technical-articles/\
the-importance-of-total-harmonic-distortion/

    Arguments:
        power_spectrum: The linear-scale (fft^2) power spectrum of the signal.

    Returns:
        The THD as a percentage number.
        Range is a percentage range, typically [0, 100], but can be larger if the signal is
        very bad.
    """
    # pylint: disable=import-outside-toplevel
    # Standard libraries
    from math import sqrt

    max_idx = power_spectrum.argmax()
    max_power = power_spectrum[max_idx]

    tone_number = 2
    overtone_power = 0.0

    while True:
        overtone_idx = max_idx * tone_number
        if overtone_idx >= power_spectrum.size:
            break

        overtone_power += power_spectrum[overtone_idx]
        tone_number += 1

    power_ratio = overtone_power / max_power
    thd_ratio = sqrt(power_ratio)
    thd_percentage = thd_ratio * 100

    return thd_percentage


def calculate_enob(value_db: float) -> float:
    """
    Calculate how many bits of digital quantization noise the given SNDR/SFDR equates.
    https://en.wikipedia.org/wiki/Effective_number_of_bits

    Arguments:
        value_db: Any value in dB scale, e.g. an SFDR.

    Returns:
        The equivalent ENOB value.
    """
    return (value_db - 1.76) / 6.02


def to_engineering_notation(value: Union[int, float]) -> str:
    """
    Convert e.g. 1048576 to "1.05 M".

    Arguments:
        value: The number to convert.

    Returns:
        The number in engineering notation.
    """
    prefixes = ["", "k", "M", "G", "T", "P", "E", "Z", "Y"]
    prefix_index = 0

    while True:
        if value < 1000:
            return f"{value:.2f} {prefixes[prefix_index]}"

        value /= 1000
        prefix_index += 1


def plot_signal_on_ax(
    ax: "Axes",
    signal: "ndarray",
    set_x_label: bool = True,
    set_y_label: bool = True,
    color: str = "tab:orange",
) -> None:
    """
    Plot and annotate the signal on the provided pre-created axes.

    https://matplotlib.org/stable/gallery/color/named_colors.html#tableau-palette
    https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.plot.html
    """
    # pylint: disable=import-outside-toplevel
    # Third party libraries
    from numpy import arange

    signal_index_axis = arange(signal.size)

    ax.plot(signal_index_axis, signal, "o-", color=color)
    ax.set_xlim([0, signal.size - 1])

    if set_x_label:
        ax.set_xlabel("Index")

    if set_y_label:
        ax.set_ylabel("Amplitude")


def plot_power_spectrum_on_ax(
    ax: "Axes",
    frequency_axis_hz: "ndarray",
    power_spectrum: "ndarray",
    peak_frequency_hz: float,
    floor_db: Optional[float] = None,
    peak_text: Optional[str] = None,
) -> None:
    """
    Plot and annotate the power spectrum on the provided pre-created axes.
    """
    # pylint: disable=import-outside-toplevel
    # Third party libraries
    from matplotlib.ticker import EngFormatter

    power_spectrum_db = power_spectrum_to_db(power_spectrum=power_spectrum)

    ax.set_title("Power spectrum")
    ax.plot(frequency_axis_hz, power_spectrum_db, "o-", color="tab:blue")
    ax.set_xlabel("Frequency")
    ax.set_ylabel("Power spectral density (dB)")
    ax.set_xlim([0, frequency_axis_hz[-1]])

    ax.xaxis.set_major_formatter(EngFormatter(unit="Hz"))

    if floor_db is not None:
        ax.axhline(y=-floor_db, color="tab:red", linestyle="--")

    if peak_text:
        text_x_offset = 0.05 * frequency_axis_hz[-1]
        if peak_frequency_hz > frequency_axis_hz[frequency_axis_hz.size // 2]:
            # Peak is in the right side of the spectrum.
            # Place the label on the left side.
            text_x = peak_frequency_hz - text_x_offset
            text_horizontal_alignment = "right"
        else:
            # Peak is in the left side of the spectrum.
            # Place the label on the right side.
            text_x = peak_frequency_hz + text_x_offset
            text_horizontal_alignment = "left"

        ax.text(
            x=text_x,
            y=-0.1 * floor_db,
            s=peak_text,
            verticalalignment="top",
            horizontalalignment=text_horizontal_alignment,
        )


class SineGeneratorResult:  # pylint: disable=too-many-instance-attributes
    def __init__(
        self, signal: "ndarray", generics: dict[str, Any], is_fractional_phase: bool
    ) -> None:
        frequency_axis_hz, power_spectrum = get_power_spectrum(
            signal=signal, sample_rate_hz=generics["clk_frequency_hz"]
        )
        sfdr_db = calculate_sfdr_db(power_spectrum=power_spectrum)

        self.frequency_axis_hz = frequency_axis_hz
        self.power_spectrum = power_spectrum
        self.sfdr_db = sfdr_db

        peak_frequency_hz, sndr_db = calculate_single_tone_sndr(
            power_spectrum=power_spectrum, frequency_axis_hz=frequency_axis_hz
        )

        # Sanity check that the detected peak is where we expect it.
        # I.e. that phase accumulation works as expected.
        sine_frequency_hz = generics["sine_frequency_hz"]
        assert (
            sine_frequency_hz * 0.9999 < peak_frequency_hz < sine_frequency_hz * 1.0001
        ), f"{peak_frequency_hz} {sine_frequency_hz}"

        self.peak_frequency_hz = peak_frequency_hz
        self.sndr_db = sndr_db
        self.sfdr_db = sfdr_db

        expected_sndr_db, expected_sfdr_db = self.get_expected_kpi(
            generics=generics, is_fractional_phase=is_fractional_phase
        )
        self.expected_sndr_db = expected_sndr_db
        self.expected_sfdr_db = expected_sfdr_db

        self.status_string = self.get_status_string(
            generics=generics, is_fractional_phase=is_fractional_phase
        )

    @staticmethod
    def get_expected_kpi(generics: dict[str, int], is_fractional_phase: bool) -> float:
        """
        Return the expected ENOB for a sine_generator test, given the provided configuration.
        """
        if is_fractional_phase:
            # Fractional phase mode. Limited by memory depth.
            sndr_enob = generics["memory_address_width"] + 1
            sfdr_enob = sndr_enob

            if generics["enable_phase_dithering"]:
                sndr_enob -= 0.5
                sfdr_enob += 3

            if generics["enable_first_order_taylor"]:
                sndr_enob = sndr_enob * 2 - 0.6
                sfdr_enob = sfdr_enob * 2

        else:
            # Integer phase mode. Limited by memory word width, which is currently hard coded in tb.
            sndr_enob = 18 + 1
            sfdr_enob = sndr_enob

        return 6 * sndr_enob, 6 * sfdr_enob

    def check(self) -> None:
        # pylint: disable=import-outside-toplevel
        # Standard libraries
        from math import isinf

        # Upper range is huge, especially when dithering is enabled.
        assert (
            self.expected_sfdr_db <= self.sfdr_db
        ), f"Unexpected SFDR. Got {self.sfdr_db}, expected {self.expected_sfdr_db}"

        if not isinf(self.sndr_db):
            assert (
                self.expected_sndr_db <= self.sndr_db < self.expected_sndr_db + 9
            ), f"Unexpected SNDR ENOB. Got {self.sndr_db}, expected around {self.expected_sndr_db}"

    @staticmethod
    def plot_signal(signal: "ndarray", coherent_sampling_count: int) -> None:
        """
        Plot the time-domain signal from test, zoomed and full, with the pre-determined layout.
        """
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from matplotlib import pyplot as plt

        ax_signal = plt.subplot2grid((2, 2), (0, 0))
        ax_signal_zoom = plt.subplot2grid((2, 2), (1, 0))

        ax_signal.set_title("Signal, full (above) and coherent section (below)")
        plot_signal_on_ax(ax=ax_signal, signal=signal, set_x_label=False, set_y_label=False)
        plot_signal_on_ax(ax=ax_signal_zoom, signal=signal[:coherent_sampling_count])

    def plot_spectrum(self) -> None:
        """
        Plot the power spectrum with the pre-determined layout.
        """
        # pylint: disable=import-outside-toplevel
        # Third party libraries
        from matplotlib import pyplot as plt

        ax = plt.subplot2grid((2, 2), (0, 1), rowspan=2)

        plot_power_spectrum_on_ax(
            ax=ax,
            frequency_axis_hz=self.frequency_axis_hz,
            power_spectrum=self.power_spectrum,
            peak_frequency_hz=self.peak_frequency_hz,
            floor_db=self.sfdr_db,
            peak_text=self.status_string,
        )

    def get_status_string(self, generics: dict[str, Any], is_fractional_phase: bool) -> str:
        sndr_enob = calculate_enob(value_db=self.sndr_db)
        sfdr_enob = calculate_enob(value_db=self.sfdr_db)
        thd_percent = calculate_thd_percent(power_spectrum=self.power_spectrum)

        if is_fractional_phase:
            mode_status = "Fractional"
        else:
            mode_status = "Integer"

        mode_status += " phase mode. "

        if generics["enable_phase_dithering"]:
            mode_status += "Dithering enabled. "
        if generics["enable_first_order_taylor"]:
            mode_status += "Taylor expansion enabled. "

        return f"""\
Clock @ {to_engineering_notation(generics["clk_frequency_hz"])}Hz, \
sine @ {to_engineering_notation(self.peak_frequency_hz)}Hz

{mode_status}

SNDR = {self.sndr_db:.2f} dB (expected {int(self.expected_sndr_db)}) = {sndr_enob:.2f} ENOB
SFDR = {self.sfdr_db:.2f} dB (expected {int(self.expected_sfdr_db)}) = {sfdr_enob:.2f} ENOB
THD = {thd_percent:.6f}%\
"""

    def __str__(self) -> str:
        return self.status_string
