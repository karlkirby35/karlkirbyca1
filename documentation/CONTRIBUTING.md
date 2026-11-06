## Contributing

The following document explains how to set up the Dropbox application locally. It includes what the project
consists of and how to implement it yourself.

# Project Overview

This project is a Dropbox application, where user's can log in, register, upload, download, rename, star and
delete files.

The application consists of:

- Frontend: React and Vite
- Backend: Node.js and Express
- Database: MySQL
- File Storage: Local storage or Amazon S3
- Deployment: Docker and AWS

## Getting Started

Ensure you have the following installed before continuing:

- Node.js 24 or later
- Npm
- Docker
- Git
- Visual Studio Code

# 1 Clone the repository

git clone https://github.com/karlkirby35/karlkirbyca1.git
cd karlkirbyca1

# 2 Start the Database

docker compose up -d db

# 3 Set up the Backend

Open a terminal and run:

cd backend
cp .env.example .env
npm install
npm run db:seed
npm run dev

The backend API runs at http://localhost:3000

# 4 Setup the Frontend

Open a second terminal from the project root:

cd frontend
cp .env.example .env
npm install
npm run dev

The frontend runs at http://localhost:5173

# Project Structure

karlkirbyca1/
├── backend/ # Express API and database logic
├── frontend/ # React user interface
├── deploy/ # Deployment scripts
├── .github/workflows/ # GitHub Actions workflows
├── compose.yml # Docker Compose configuration
└── README.md # Main project documentation

# Testing and Code Quality

Backend:

cd backend
npm run lint
npm run format:check
npm test -- --run

Frontend:

cd frontend
npm run lint
npm run format:check
npm run build

If formatting fails, use npm run format in the directory to check the changes before committing.

# Making Changes

1: Create a new branch for changes
2: Test the changes locally before deploying it live
3: Commit message should be clear with whats being committed
4: Push the branch to Github
5: Compare and pull request will show at the top of the code section on Github
6: Open the pull request and name it what you are adding
7: Wait for the 3 checks to pass, which are docker, frontend and backend
8: After the checks pass merge the request to the main branch

Example request:

git checkout -b feature/file-improvements
git add .
git commit -m "Improve file management functionality"
git push -u origin feature/file-improvements

# Continuous Integration and Deployment

The repository uses github actions where the pull requests are managed. This allows for automated code quality
checks and deployment. The automated deployments make manual deployments faster and easier for the user.

The checks workflow runs on pull requests and pushes to the main branch. It checks backend linting, formatting
and tests and validates the frontend build.

The deployment workflow builds and publishes a Docker image to Amazon ECR and deploys the application to AWS EC2.

Changes that are made should be tests before they are merged to the main branch, such as rollsbacks etc.

# Reporting Issues

To report a bug, open a Github issue and include:

- a description of the problem
- steps you took
- what you expected to happen
- any error messages you encountered
