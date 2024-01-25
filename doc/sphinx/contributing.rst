Contribution guide
==================

Information on how to make contributions to the ``hdl-modules`` project.


.. _maintain_changelog:

Maintaining changelog
---------------------

We maintain a changelog according to the `keep a changelog <https://keepachangelog.com/>`__ format.
The unreleased changelog in ``doc/release_notes/unreleased.rst`` shall be updated continuously,
not just at release.
Release note files are in the ``rst`` format, inspect older release note files to see the
formatting details.


How to make a new release
-------------------------

Stable versions are "released" by marking with a git tag.
To make a new release follow these steps.


Test CI pipeline
________________

Before doing anything, launch a CI run from the ``main`` branch to see that everything works
as expected.
The CI environment is stable but due to things like, e.g., new pylint version it can
unexpectedly break.
When the pipeline has finished and is green you can move on to the next step.


Review the release notes
________________________

Check the release notes file ``unreleased.rst``.
Fill in anything that is missing according to :ref:`Maintaining changelog <maintain_changelog>`.


Determine new version number
____________________________

We use the `Semantic Versioning <https://semver.org/>`__ scheme.
Read the **Summary** at the top of that page and decide the new version number accordingly.


Run release script
__________________

Run the script

.. code-block:: shell

    python3 tools/tag_release.py X.Y.Z

where X.Y.Z is your new version number.
The script will copy release notes to a new file, and commit and tag the changes.


Push tag and commits
____________________

Assuming you have just performed a CI run, as instructed above, you can now push the tag.

.. code-block:: shell

    git push origin vX.Y.Z

**WARNING:** Avoid the "git push --tags" command, which is dangerous since it pushes all your
local tags.

This next step is unnecessarily crude due to the fact that GitHub does not allow a fast-forward
merge in their Pull Request web UI.
A GitHub repo with linear history will use the "rebase and merge" strategy, which changes the SHA
of the commits.
Hence, the tag that we just pushed will not match any commit on the main branch, if we merge our
release commit via the web UI.
(See https://stackoverflow.com/questions/60597400).

Instead, this has to be done manually on the command line, and can only be done by a user with
complete privileges to the repository.

.. code-block:: shell

    git push origin HEAD:main

**WARNING:** Be very careful with this command and inspect locally that you do not push anything
else than intended.
