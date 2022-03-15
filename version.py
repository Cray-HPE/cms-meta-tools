#!/usr/bin/env python3
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

"""
The sum of the whole is greater than its parts.

This script generates a version using a variety of predefined strategies with as little hand-holding
as possible. The strategies are defined ahead of time, but can be influenced at specific points in
time to allow for the greatest flexibility, with both developer and release branches in mind.

The versioning goals here include:
- Unique versions with every commit (where possible)
- Monotonically increasing (where possible)
- Automatic (where possible)

NOTE: This does NOT spit out a build version. That's the responsibility of a build system.
WARNING: You copy this file, you own it.

original author: jsl
"""

import subprocess
import os
import re
import sys
from distutils.version import LooseVersion

THIS_FILE = __file__
THIS_PROJECT = os.getcwd()

def myprint(s):
    """
    Allows us to print status or informational messages
    """
    print("version.py: %s" % s, file=sys.stderr)


def branch_name():
    """
    Obtains a copy of the name of the current branch; make it work with all DST build pipelines.
    """
    return subprocess.check_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], cwd=THIS_PROJECT).decode('UTF-8').rstrip()


class VersionStrategy():
    """
    A Version strategy yields exactly one value, and ideally corresponds to one number.
    
    This class is intended to be inherited, so multiple types of versioning strategies
    can be used together.

    VersionStrategies __call__ should resolve to either a String or the None type. When
    evaluating VersionStrategies, NoneTypes are skipped over in favor of the next available
    defined strategy for a given field, within the context of a given overall Version.
    """
    def __init__(self, field):
        """
        A Field is simply the x, y, or z position of a given version.
        """
        self.field = field

    def myprint(self, s):
        """
        Wrapper to global myprint function, prepending the class name
        """
        myprint("%s: %s" % (type(self).__name__, str(s)))

    @property
    def field_index(self):
        """
        The 0-ordered position for this field. Fields without a known position are defined to be -1.
        """
        return 'xyz'.find(self.field)

    def __call__(self):
        raise Exception("Strategy does not have a value method defined.")


class ZeroStrategy(VersionStrategy):
    """
    A Zero strategy is used when we need a version field, but it doesn't make sense to
    ever increment or look it up. This is most useful for branches that should not be
    built or installed anywhere in particular.

    This Strategy is used for master and main branches that are never to be released or
    installed onto systems.
    """
    def __call__(self):
        return '0'


class PinnedFileStrategy(VersionStrategy):
    """
    A pinned version is simply referenced by a named file within a local checkout that
    a user sets at a specific time. This is the simplest replication of the old .version
    file, where a user sets it, generally, once per branch, and then leaves it alone.

    A pinned file corresponds to the field given, and is generally a .x, a .y, or a .z file.

    This strategy should be used sparingly, as a pinned version MUST be maintained separately
    and manually. Generally speaking, a pinned version always wins, but provides the least
    amount of automatic versioning.

    Otherwise known as the "I know better than you" strategy of versioning.
    """
    @property
    def pinned_path(self):
        return '.%s' %(self.field)

    def __call__(self):
        if not os.path.exists(self.pinned_path):
            self.myprint("File '%s' does not exist" % self.pinned_path)
            return None
        self.myprint("Reading file '%s'" % self.pinned_path)
        with open(self.pinned_path, 'r') as pinned_file:
            version = pinned_file.read().strip()
            self.myprint("Read string '%s'" % version)
            return version


class GitBasedStrategy(VersionStrategy):
    """
    Git-based strategies look at branch and commit history information in order to devise
    the value of a given field. Due to the nature of GitBasedStrategies, they can only
    be created when the git project checkout is clean. Any uncommitted file in your project
    will cause a GitBasedStrategy to ultimately produce artifacts that are not representative
    of the project.

    In these cases, we could fail the build, but ultimately there are always going to be
    '.' files that are not intended to be checked in, or intermediate build files that are in
    a local checkout that can affect the overall outcome.

    Finally, this strategy implements a number of wrappers to git commands that can be used
    by subsequent git commands to make sense of the project.
    """
    @property
    def git_status(self):
        """
        Returns the output of git status for a project in the form of porcelain=2
        """
        return subprocess.check_output(['git', 'status', '--porcelain=2'], cwd=THIS_PROJECT).decode('UTF-8')

    @property
    def is_clean(self):
        return len(self.git_status.split('\n')) == 0

    @property
    def branch(self):
        """
        The name of the branch in the local checkout. Discovered exactly once per invocation.
        """
        return branch_name()

    @property
    def commits(self):
        """
        Returns a list of commits that are part of this branch.
        """
        return subprocess.check_output(['git', 'log', '--pretty=format:%H'], cwd=THIS_PROJECT).decode('UTF-8').splitlines()


class DeveloperBranchNameStrategy(GitBasedStrategy):
    """
    DeveloperBranchNameStrategy can inform version information for Developer Branches:
    CASMCMS-1234 -> 0.CASMCMS-1234.0
    CASMINST-1234 -> 0.CASMINST-1234.0

    These version strings are unique as they contain alphanumeric characters to better assist in tracking
    an installed version back to a specific issue.

    This strategy is used in conjunction with commit-counting strategies to form a full version string..
    """
    def __call__(self):
        if self.field_index in (0, 2):
            return None # We only work on 'y' components, sorry.
        return str(self.branch)


class DeveloperBranchOnlyDigitsStrategy(DeveloperBranchNameStrategy):
    """
    Like a DeveloperBranchNameStrategy, but the fields are stripped of alphanumeric characters.
    """
    def __call__(self):
        value = super().__call__()
        self.myprint("value = '%s'" % value)

        # Remember the original value, so that we can compare it at the end, and print the
        # revised value if applicable
        orig_value = value

        value = re.sub('[^0-9]', '', value)
        if value:
            # Strip leading 0s, because they aren't allowed in SemVer 2.0
            value = re.sub("^00*", "0", value)
        else:
            # Return 0 if all else fails (i.e. the above modifications leave us with a blank string)
            value = "0"
        if value != orig_value:
            self.myprint("After modifications, value = '%s'" % value)
        return value


class CommitCountStrategy(GitBasedStrategy):
    """
    Produces a version field based on the number of commits that have been made to a branch.
    """
    def __call__(self):
        num_commits = str(len(self.commits))
        self.myprint("number of commits = %s" % num_commits)
        return num_commits


class CommitsFromParentBranch(GitBasedStrategy):
    """
    Counts the number of commits you have made to your local branch (including merges!)
    as a value. This is a rough estimate about the number of individual commits that have been made
    since you branched from the upstream origin branch.
    
    NOTE: This value can change if you merge your code into the upstream remote and then pull it back down!
    Therefore, it may not be monotonically increasing.
    """
    @property
    def parent_branch(self):
        value = subprocess.check_output(['git', 'config', '--get-regex', 'branch.%s.merge' %(self.branch)], cwd=THIS_PROJECT).decode('UTF-8').strip().strip()
        branch = '/'.join(value.split('/')[2:])
        self.myprint("parent_branch = '%s'" % branch)

    @property
    def commits_from_parent(self):
        num_commits = subprocess.check_output(
            ['git', 'rev-list', '--count', self.branch, '--not', 'origin/%s' %(self.parent_branch)],
            cwd=THIS_PROJECT).decode('UTF-8').strip()
        self.myprint("number of local branch commits = %s" % num_commits)
        return num_commits

    def __call__(self):
        try:
            return self.commits_from_parent
        except subprocess.CalledProcessError:
            return None


class CommitsSinceChangedStrategy(GitBasedStrategy):
    """
    This is a unique strategy to the 'z' field, and is the magic behind automatic increments
    to the same branch.

    This strategy requires a referenced 'PinnedFileStrategy' approach for the version immediately
    to the left (more significant version). Most commonly, the magic number is used to find the
    z version by examining the pinned y file.

    When a pinned y file changes as part of a commit, we count the number of commits to this branch
    in order to determine this value. Most importantly, this allows developers to commit code to
    the same branch without major consideration for manually incrementing ANY file. The benefit
    of doing this is that it allows asynchronous merges to happen without a merge conflict. Values
    are simply handed out somewhat monotonically, and follow the merge order for the given
    branch.

    The beauty of this approach is that the default behavior of bumping the minor version ('y')
    using a pinned approach automatically sets this value back to zero.
    """
    @property
    def significant_neighbor(self):
        try:
            return 'xyz'[self.field_index-1]
        except KeyError:
            raise Exception("CommitsSinceChangedStrategy cannot reference a more significant field.")

    @property
    def neighbor_pinned_strategy(self):
        return PinnedFileStrategy(self.significant_neighbor)

    @property
    def neighbor_pinned_last_commit(self):
        """
        Introspects the git history for the commit hash for the last change to affect our parent
        pinned version.
        """
        last_commit = subprocess.check_output(
            ['git', 'log', '--pretty=format:%H', '-n1', self.neighbor_pinned_strategy.pinned_path], 
            cwd=THIS_PROJECT).decode('UTF-8').strip()
        self.myprint("Last commit to affect '%s' was '%s'" % (self.neighbor_pinned_strategy.pinned_path, last_commit))
        return last_commit

    @property
    def commits_since_neighbor_changed(self):
        commit_list = self.commits
        change_commit = self.neighbor_pinned_last_commit
        commit_index_matches = list(filter(lambda index: commit_list[index] == change_commit, range(len(commit_list))))
        # There _should_ be exactly one match :)
        commits_since_neighbor_changed = commit_index_matches[0]
        self.myprint("commits_since_neighbor_changed = %s" % str(commits_since_neighbor_changed))
        return commits_since_neighbor_changed

    def __call__(self):
        nps = self.neighbor_pinned_strategy
        if not os.path.exists(nps.pinned_path):
            self.myprint("File does not exist: '%s'" % (nps.pinned_path))
            return None # In short, if the more significant version is not pinned, we can't count
                        # the commits against it since its changed!
        return str(self.commits_since_neighbor_changed)


class BranchVersion(LooseVersion):
    """
    Every branch has its own unique desired set of strategies that need
    to work together to form a cohesive version, and the strategies are different
    based on what kind of branches there are.

    Today, we define three types of branches:
    - master branch
    - release branch
    - developer branch

    Depending on the kind of branch you have (as defined by the name), you can expect different
    but wholly consistent behaviors.
    
    This is a base class intended to be inherited by separate BranchVersion class definitions.
    """
    def __init__(self):
        self.x_strategies = []
        self.y_strategies = []
        self.z_strategies = []

        # Cached Value Holders
        self._x = None
        self._y = None
        self._z = None

    def myprint(self, s):
        """
        Wrapper to global myprint function, prepending the class name
        """
        myprint("%s: %s" % (type(self).__name__, str(s)))

    def evaluate_strategies(self, strategies):
        """
        Serially evaluates strategies in the passed list of strategies until one of them
        resolves to a non-None value.
        """
        for strategy in strategies:
            value = strategy()
            if value:
                return value

    @property
    def x(self):
        if self._x:
            return self._x
        self.myprint("Determing major version number")
        self._x = self.evaluate_strategies(self.x_strategies)
        self.myprint("Major version number = %s" % self._x)
        return self._x

    @property
    def y(self):
        if self._y:
            return self._y
        self.myprint("Determing minor version number")
        self._y = self.evaluate_strategies(self.y_strategies)
        self.myprint("Minor version number = %s" % self._y)
        return self._y

    @property
    def z(self):
        if self._z:
            return self._z
        self.myprint("Determing patch version number")
        self._z = self.evaluate_strategies(self.z_strategies)
        self.myprint("Patch version number = %s" % self._z)
        return self._z

    @property
    def all_fields(self):
        return (self.x, self.y, self.z)

    def __repr__(self):
        return '%s.%s.%s' % self.all_fields

    def __call__(self):
        self.myprint("Version = %r" % (self))
        print('%r' %(self))


class MasterBranchVersion(BranchVersion):
    """
    A master branch should never be released or installed (who does that?!). Although it is
    almost always the bleeding edge of commits, it's never the latest. We always want this
    version to be less than anything else.

    Same thing goes for 'main' branches as well; we treat these synonymously as far as versioning
    goes, however, not all builds from master or main are the same, and we want to show some kind
    of minor change mark on produced artifacts to suggest when something may have been built.
    """
    @staticmethod
    def is_a(branch_name):
        return branch_name in ('master', 'main')

    def __init__(self):
        super().__init__()

        # We never want to release this, so make the version number small
        self.x_strategies.append(ZeroStrategy('x'))
        self.y_strategies.append(ZeroStrategy('y'))

        # Make the zed version become the number of commits that are in this branch
        self.z_strategies.append(CommitCountStrategy('z'))


class ReleaseBranchVersion(BranchVersion):
    """
    A Release branch version is intended to be externally shipped to customers; these branches
    represent the focal point of developer integration and have the highest need for asynchronous
    but consistent monotonically increasing versions.
    """
    @staticmethod
    def is_a(branch_name):
        return branch_name.startswith('release/')

    @property
    def z(self):
        if self._z:
            return self._z
        self.myprint("Determing patch version number")
        self._z = self.evaluate_strategies(self.z_strategies)
        self.myprint("z value = '%s'" % self._z)
        if os.path.exists(".z_offset"):
            # If there is a z_offset file we want to add it to our calculated z value
            # This is primarily useful to avoid having dynamic version numbers collide
            # with previously used static version numbers
            self.myprint("Found .z_offset file. Reading it")
            with open(".z_offset", "rt") as z_offset_file:
                offset = z_offset_file.read().strip()
                self.myprint("Read string '%s'" % offset)
            self._z = str(int(offset) + int(self._z))
        else:
            # If there is no offset file, no problem
            self.myprint("No .z_offset file")
        self.myprint("Patch version number = %s" % self._z)
        return self._z

    def __init__(self):
        super().__init__()
        self.x_strategies.append(PinnedFileStrategy('x'))
        self.y_strategies.append(PinnedFileStrategy('y'))
        self.z_strategies.append(CommitsSinceChangedStrategy('z'))
                

class DeveloperBranchVersion(BranchVersion):
    """
    Developer branches have a need to be built and installed in order to be tested,
    but developer branches shouldn't release to anyone other than originating authors.
    For traceability purposes, the issue ticket (JIRA/Github) ideally has some influence
    on the versioning, so that commits to the same issue can be tracked in a common
    location.

    We also would like developer branches to increment as a developer makes iterative changes,
    with an initial developer branch getting a .0 suffix.
    CASMCMS-1234 -> 0.CASMCMS-1234.0
    CASMCMS-1234 + 2 developer commits -> 0.CASMCMS-1234.2
    CASMINST-567 -> 0.CASMINST-567.0

    Note: It's possible to overlap built issues based on two different ticket providers or identifiers.
    """
    @staticmethod
    def is_a(self):
        return True # We're not picky.

    @property
    def y(self):
        if self._y:
            return self._y
        self.myprint("Determing minor version number")
        yval = self.evaluate_strategies(self.y_strategies)
        if yval == '0':
            # Dev branches already have a major number of 0. We do not want them
            # to also have a minor number of 0, because we reserved 0.0.z for master
            yval='1'
        self._y = yval
        self.myprint("Minor version number = %s" % self._y)
        return self._y

    def __init__(self):
        super().__init__()
        self.x_strategies.append(ZeroStrategy('x')) # We don't release our stuff! Stay below 0.
        self.y_strategies.append(DeveloperBranchOnlyDigitsStrategy('y'))
        self.z_strategies.append(CommitsFromParentBranch('z'))
        # Our build system can't handle a lookup against origin, so we just look at commit count
        self.z_strategies.append(CommitCountStrategy('z'))


def version_factory():
    branch = branch_name()
    myprint("branch = %s" % branch)
    # If the TAG_NAME environment variable exists and is not blank, then we consider ourselves
    # to be in a release branch
    tag_name = os.environ.get('TAG_NAME', False)
    if tag_name:
        myprint("TAG_NAME environment variable set to %s" % tag_name)
        return ReleaseBranchVersion()
    elif MasterBranchVersion.is_a(branch):
        myprint("Looks like the master branch")
        return MasterBranchVersion()
    elif ReleaseBranchVersion.is_a(branch):
        myprint("Looks like a release branch")
        return ReleaseBranchVersion()
    else:
        myprint("Looks like a developer branch")
        return DeveloperBranchVersion()

if __name__ == '__main__':
    version_factory()()
