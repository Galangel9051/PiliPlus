<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png" alt="PiliPlus logo">
    <h1>PiliPlus</h1>
</div>

<div align="center">

[中文](README.md) | English

![GitHub repo size](https://img.shields.io/github/repo-size/Galangel9051/PiliPlus)
![GitHub Repo stars](https://img.shields.io/github/stars/Galangel9051/PiliPlus)
![GitHub all releases](https://img.shields.io/github/downloads/Galangel9051/PiliPlus/total)
[![fork of](https://img.shields.io/badge/fork%20of-bggRGjQaUbCoE%2FPiliPlus-blue)](https://github.com/bggRGjQaUbCoE/PiliPlus)

</div>

<div align="center">
    <p>A third-party Bilibili client built with Flutter</p>

<img src="assets/screenshots/510shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="PiliPlus desktop screenshot" />
<br/>
</div>

<br/>

> [!IMPORTANT]
> **This repository is a fork of [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus). It is not the upstream project and does not represent the upstream maintainers.**

## About This Fork

This repository is maintained by [@Galangel9051](https://github.com/Galangel9051) for personal builds and customization. It may contain local changes that have not been merged upstream.

- **For a stable, complete, officially supported build**: head to the upstream repository [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus).
- **This repository**: mainly for the author's own use. The `main` branch is always the latest state; differences from upstream are expected.
- **Reporting issues**: issues caused by changes in this fork belong in this repository's [Issues](https://github.com/Galangel9051/PiliPlus/issues). Issues shared with upstream should be reported upstream first.

### Syncing with upstream

Upstream updates are merged manually from time to time:

```bash
git remote add upstream https://github.com/bggRGjQaUbCoE/PiliPlus.git
git fetch upstream
git merge upstream/main        # or: git rebase upstream/main
git push origin main
```

## Download

Download a build from [Releases](https://github.com/Galangel9051/PiliPlus/releases) (if this fork has no release yet, use the upstream [Releases](https://github.com/bggRGjQaUbCoE/PiliPlus/releases)), or clone the repository and build it locally.

## Building Locally

Flutter `3.47.6` is required (the repo ships a `.fvmrc`, so [fvm](https://fvm.app/) is recommended):

```bash
git clone https://github.com/Galangel9051/PiliPlus.git
cd PiliPlus
fvm install && fvm flutter pub get     # or plain: flutter pub get
fvm flutter build apk --release        # Android
```

See the corresponding workflows under `.github/workflows/` for Windows / Linux / macOS / iOS builds.

## Disclaimer

PiliPlus is a personal project developed for educational purposes, intended only for learning and testing. Please delete it within 24 hours of downloading.
All APIs used were collected from the official website. This project does not provide any cracked content.

Credit to the original project: [guozhigq/pilipala](https://github.com/guozhigq/pilipala).
Credit to the upstream project: [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX).
Credit to the source repository: [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus).
This repository makes more extensive changes on top of upstream. Thank you to the original authors for sharing their work as open source.

All code in this repository is inherited from the upstream open-source project and follows the original [LICENSE](LICENSE); no additional rights are claimed.

Thank you for using PiliPlus.

## Acknowledgements

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- And others

## Star History

<a href="https://star-history.dera.page/#Galangel9051/PiliPlus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=Galangel9051/PiliPlus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=Galangel9051/PiliPlus&type=Date" />
   <img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=Galangel9051/PiliPlus&type=Date" />
 </picture>
</a>
