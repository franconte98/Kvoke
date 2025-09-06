<a id="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![Unlicense License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<br />
<div align="center">
  <a href="https://github.com/othneildrew/Best-README-Template">
    <img src="Resources/Logo-Kinit.png" alt="Logo" width="400">
  </a>
</div>

## Overview

Kinit is a powerful, open-source Infrastructure as Code (IaC) tool designed to simplify the deployment of on-premise Kubernetes clusters. It eliminates the complexities of manual setup, allowing you to build a production-ready cluster with minimal effort.

Kinit streamlines the entire process into a few simple steps:

1. <ins>Meet the Prerequisites:</ins> Ensure you have the minimal infrastructure required, as outlined in the Prerequisites section.

2. <ins>Fill out the Form:</ins> Use our intuitive UI to define your cluster's specifications.

3. <ins>Deploy:</ins> Kinit handles the rest, automating the entire cluster creation process.

With Kinit, building a Kubernetes cluster is as easy as filling out a form, making advanced infrastructure accessible to everyone.

### Choose Your Container Runtime

Kinit gives you the flexibility to build your cluster with the container runtime that best fits your needs. You can easily choose between:

- Docker 🐳

- Containerd 📦

- CRI-O 🐧

### Tailor Your Infrastructure for High Availability

Beyond container runtimes, Kinit lets you select the cluster configuration that aligns with your specific high-availability (HA) and reliability requirements.

#### Simple Configuration

This is a standard setup with a single control plane. It’s an ideal solution for development, testing, or scenarios where high availability isn't the primary concern. It provides a solid, minimal-footprint cluster that's quick to deploy and easy to manage.

#### Stacked ETCD Configuration

For environments that demand high availability, the Stacked ETCD configuration is the perfect choice. This setup features multiple control planes, with leader election managed automatically via Keepalived. It's a robust solution for a production workload where you need HA without the overhead of a massive infrastructure.

## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites

This is an example of how to list things you need to use the software and how to install them.
* npm
  ```sh
  npm install npm@latest -g
  ```

### Installation

_Below is an example of how you can instruct your audience on installing and setting up your app. This template doesn't rely on any external dependencies or services._

1. Get a free API Key at [https://example.com](https://example.com)
2. Clone the repo
   ```sh
   git clone https://github.com/github_username/repo_name.git
   ```
3. Install NPM packages
   ```sh
   npm install
   ```
4. Enter your API in `config.js`
   ```js
   const API_KEY = 'ENTER YOUR API';
   ```
5. Change git remote url to avoid accidental pushes to base project
   ```sh
   git remote set-url origin github_username/repo_name
   git remote -v # confirm the changes
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

Use this space to show useful examples of how a project can be used. Additional screenshots, code examples and demos work well in this space. You may also link to more resources.

_For more examples, please refer to the [Documentation](https://example.com)_

## License

Distributed under the Unlicense License. See `LICENSE.txt` for more information.

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/othneildrew/Best-README-Template.svg?style=for-the-badge
[contributors-url]: https://github.com/othneildrew/Best-README-Template/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/othneildrew/Best-README-Template.svg?style=for-the-badge
[forks-url]: https://github.com/othneildrew/Best-README-Template/network/members
[stars-shield]: https://img.shields.io/github/stars/othneildrew/Best-README-Template.svg?style=for-the-badge
[stars-url]: https://github.com/othneildrew/Best-README-Template/stargazers
[issues-shield]: https://img.shields.io/github/issues/othneildrew/Best-README-Template.svg?style=for-the-badge
[issues-url]: https://github.com/othneildrew/Best-README-Template/issues
[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=for-the-badge
[license-url]: https://github.com/othneildrew/Best-README-Template/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/othneildrew
[product-screenshot]: images/screenshot.png