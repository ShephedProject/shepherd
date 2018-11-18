Contributing
============

For non-Github-organisation developers, we use the Git/Github Fork & Pull request model. 
**Please use topic branches on your fork**. 

For those new to Git/Github, please read the help section, primarily [Forking a repo](https://help.github.com/articles/fork-a-repo/)
& [About Pull Requests](https://help.github.com/articles/about-pull-requests/).

By contributing you agree to license your contributions under the GNU GPL v3, as specified in [COPYING](COPYING) &
[LICENSE](LICENSE) by the original author(s).

## Release Model
Given Shepherd self updates, we leverage Github's ability to download raw files using 2 branches (plus master).

### master
Main development branch or "bleeding edge", Shepherd will not auto update from this, git checkouts only.
If you run Shepherd from this you should disable auto update. Things are **likely to break**.

All external pull requests should go here.

### staging
Testing grounds for 'releases'. Shepherd should be able to use this as a source. **Possible** for things to break (better to break here than release).
You can set your Shepherd to use this source, but it is mainly for devs to test that their update won't brick any installs.

**Organisation Devs**: merge master to here, then run [generate_status_csum](util/generate_status_csum).

### release
General public release channel. Updates should not break user installs by misconfiguration.

**Organisation Devs**: This should be a Fast-Forward branch only.