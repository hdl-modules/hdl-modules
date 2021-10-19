Contribution guide
==================

Information on how to make contributions to the ``hdl_modules`` project.


.. _maintain_changelog:

Maintaining changelog
---------------------

We maintain a changelog according to the `keep a changelog <https://keepachangelog.com/>`__ format.
The unreleased changelog in ``doc/release_notes/unreleased.rst`` shall be updated continuously, not just at release.
Release note files are in the ``rst`` format, inspect older release note files to see the formatting details.


How to make a new release
-------------------------

Stable versions are "released" by marking with a git tag.
To make a new release follow these steps.


Test CI pipeline
________________

Before doing anything, launch a CI run from master to see that everything works as expected.
The CI environment is stable but due to things like, e.g., new pylint version it can unexpectedly break.
When the pipeline has finished and is green you can move on to the next step.


Determine new version number
____________________________

We use the `Semantic Versioning <https://semver.org/>`__ scheme.
Read the **Summary** at the top of that page and decide the new version number accordingly.


Review the release notes
________________________

Check the release notes file ``unreleased.rst``.
Fill in anything that is missing according to :ref:`Maintaining changelog <maintain_changelog>`.


Run release script
__________________

Run the script

.. code-block:: shell

    python3 tools/tag_release.py X.Y.Z

where X.Y.Z is your new version number.
The script will copy release notes to a new file, and commit and tag the changes.


Push commit and tag
___________________

.. code-block:: shell

    git push origin --tag vX.Y.Z HEAD:release_branch

Open a new merge request and wait for the CI pipeline to pass.
If everything went well then you can merge your release commit to master via the gitlab merge request GUI.
