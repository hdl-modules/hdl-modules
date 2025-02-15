# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# ruff: noqa: INP001

from typing import Callable

import matplotlib.pyplot as plt
import numpy as np

# Plot a little bit bigger than the unit circle.
PLOT_SIZE = 1.5

X_AXIS = np.linspace(0, 2 * np.pi, 100)

FONT_SIZE = 15


def plot_unit_circle(
    ax: plt.Axes, original_angles: list[float], offset_angles: list[float]
) -> None:
    ax.set_xlim(-PLOT_SIZE, PLOT_SIZE)
    ax.set_ylim(-PLOT_SIZE, PLOT_SIZE)
    ax.set_xticks([])
    ax.set_yticks([])

    # Draw center axis.
    ax.axhline(y=0, color="black", linewidth=0.5)
    ax.axvline(x=0, color="black", linewidth=0.5)

    # Annotate the quadrants.
    text_location = 0.7 * PLOT_SIZE
    ax.annotate("0", xy=(text_location, text_location), fontsize=FONT_SIZE)
    ax.annotate("1", xy=(-text_location, text_location), fontsize=FONT_SIZE)
    ax.annotate("2", xy=(-text_location, -text_location), fontsize=FONT_SIZE)
    ax.annotate("3", xy=(text_location, -text_location), fontsize=FONT_SIZE)

    # Plot the unit circle.
    ax.plot(np.cos(X_AXIS), np.sin(X_AXIS), color="tab:green")

    for angle in original_angles:
        ax.plot(np.cos(angle), np.sin(angle), marker="o", color="tab:blue")

    for angle in offset_angles:
        x = np.cos(angle)
        y = np.sin(angle)
        ax.plot(x, y, marker="o", color="tab:red")
        ax.plot([0, x], [0, y], color="tab:gray", linestyle="--", linewidth=0.5)

    ax.set_aspect("equal")


def plot_sinusoid(ax: plt.Axes, angles: list[float], function: Callable, add_text: bool) -> None:
    ax.set_xlim(0, 2 * np.pi)
    ax.set_ylim(-PLOT_SIZE, PLOT_SIZE)
    ax.set_xticks([])
    ax.set_yticks([])

    ax.plot(X_AXIS, function(X_AXIS), color="tab:green")

    for angle in angles:
        x = angle
        y = function(angle)
        ax.plot(x, y, marker="o", color="tab:red")
        ax.plot([x, x], [0, y], color="tab:gray", linestyle="--", linewidth=0.5)

    ax.axhline(y=0, color="black", linewidth=0.5)

    quadrant_x_increment = np.pi / 2
    for quadrant_idx in range(4):
        quadrant_x = quadrant_idx * quadrant_x_increment
        ax.axvline(x=quadrant_x, color="black", linewidth=0.5)

        if add_text:
            ax.annotate(
                str(quadrant_idx),
                xy=(quadrant_x + quadrant_x_increment / 2, PLOT_SIZE * 2 / 3),
                fontsize=FONT_SIZE,
            )


def main() -> None:
    plt.figure(figsize=(15, 7))

    ax_unit_circle = plt.subplot2grid((2, 2), (0, 0), rowspan=2)
    ax_sine = plt.subplot2grid((2, 2), (0, 1))
    ax_cosine = plt.subplot2grid((2, 2), (1, 1))

    num_points = 12
    phase_increment = 2 * np.pi / num_points
    phase_offset = phase_increment / 2

    original_angles = [phase_increment * angle_idx for angle_idx in range(num_points)]
    offset_angles = [original_angle + phase_offset for original_angle in original_angles]

    plot_unit_circle(
        ax=ax_unit_circle, original_angles=original_angles, offset_angles=offset_angles
    )
    plot_sinusoid(ax=ax_sine, angles=offset_angles, function=np.sin, add_text=True)
    plot_sinusoid(ax=ax_cosine, angles=offset_angles, function=np.cos, add_text=False)

    plt.show()


if __name__ == "__main__":
    main()
