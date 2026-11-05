## 1 System Overview

The application is a cloud-based file storage system that works using docker. The user can upload, delete
and favourite files they upload to the website.

The application React for the frontend user interface and Node.js with express, which handles the backend
operations and API requests.

MySQL is used as the relational database to store user information and file metadata, while the file
contents are stored seperately through the S3 bucket on AWS and supported with local storage controlled
by STORAGE_DRIVER.

The application is containerised using Docker, allowing the site to work locally through a local host link.
The deployment process uses Amazon ECR to store Docker images, EC2 to host the application, Cloudfront to
provide access to the application and Github Actions to automate building and deploying updates.

---

## 2 System Architecture

The application has a React frontend, an Express backend and a MYSQL database and a file storage system
The Frontend is the user interface and what the user sees when they log into the dropbox application, the
Backend handles the requests from the Frontend when the user clicks on requests on the interface.

MYSQL is responsible for storing the file information and the user information when a file is uploaded
to the dropbox application. The actual file is stored using either local storage or the S3 bucket on AWS, depending
on the storage method configured for the application.

Docker is used to containerise the application and is run locally through localhost:8080:80. During
local development Docker manages the react frontend, express backend and the MYSQL services.

For cloud deployment, EC2 manages running the container for the application. Amazon Cloudfront is
configured to allow access to the application, while Amazon ECR stores the Docker images during
deployment.

The architecture seperates the user interface, application logic, database and file storage making
the app easier to maintain and deploy.

---

## 3 Frontend Architecture

The frontend of the application is developed using React and manages the user interface. This includes
buttons, the search bar and the other interactive elements in the application.

The frontend is organised into seperate folders so viewing each function is easy and maintainable.

The pages directory contains the main application screens, which includes the account information page,
the files page where uploaded files are showed, login page where the user can login, register page
where the user can register with dropbox and the not found page which is shown if the user vists an
invalid page.

The componenets directory stores information that is reusable through the application, such as buttons, the
file list, the application layout and the file details.

The api directory handles communication with the backend. The auth.js file manages authentication requests and
the files.js handles file related requests. The client.js file sends these requests to the backend which uses
Express API.

The application also uses React Context through AuthContext.js to manage authentication information and to keep
track of the currently logged in user.

---

## 4 Backend Architecture

The backend structure is seperated into three different folders to maintain easy access to each part of the code.
The backend is built using Node.js and Express.

The server.js file starts the backend server, by importing the Express application and tells it to listen on the
port that is inputted in config.js. The app.js file allows the backend to read JSON data sent by the frontend
and connects the authentication, storage and the file routes.

The backend has 3 different jobs, which include Routes, Controllers and Services.

# 4.1 Routes

There are three route files,
including auth.routes.js which handles registering an account, logging in and managing the user details. The
files.route.js handles the file management within the application. This includes listing files, uploading files,
starring files and deleting files.

The storage.routes.js accessess the stored files. When using local storage,
this allows the frontend to access files through temporary signed links. When using S3 the backend creates
links that point directly to S3 instead.

# 4.2 Controllers

The controllers handle the request received from the route. They communicate with the services to carry out
the requested actions and then send a response back to the frontend.

There are two main controllers used in the application. The auth.controller.js handles account related requests,
such as registeration, logging in and updating the user details. The files.controller.js handles file related requests,
such as listing, uploading, updating and deleting files.

There is also a storage.controller.js which handles requests to access files saved using local storage.

# 4.3 Services

The services contain the actual logic of the backend and handle the work requested by the controllers.

There are three main service files:

auth.service.js handles user account, including registering users, checking login details, updating account information
and changing passwords.
files.service.js handles the file information stored in the database. This includes listing files, searching, checking
storage limits, starring and renaming and deleting files

storage.service.js manages where the actual files are stored. It supports both local storage on the server and S3 bucket
storage

---

## 5 Database Architecture

The application uses MYSQL to store and manage information. The database contains two more tables, which are the users table
and the files table.

The users table stores information when a user creates an account. This includes the user's email address, password hash, their
first and last name, profile picture and their storage quota. Each user is given a unique ID to identify their account.

The files table stores the information about the files that are uploaded. This includes the file name, file type, file size,
storage location reference and whether the file has been starred.

The two tables are connected using user_id, which acts as a foreign key in the files table. This links each uploaded file
to the user who owns it. This creates a one to many relationship, meaning one user can have multiple files, while each file
belongs to the user.

The database does not store the actual uploaded files, they are stored in the S3 Bucket and also on the local storage
with STORAGE_DRIVER. The databse stores the information
about the file and a storage key that identifies where the file is saved.

The application also uses Drizzle ORM to communicate with MYSQL. The db.js file creates the database connection, while schema.js
defines the structure of the databses tables. Database migrations are used to apply changes to the structure.

---

## 6 File Storage Architecture

The application supports two different methods of storing uploaded files:Local storage and Amazon S3.

Local storage saves uploaded files directly onto the server running the application. The backend stores the information
about the file in the MYSQL database, including its original name, file, size and storage key.

The application also supports Amazon S3, which is a cloud storage service built into AWS. Instead of saving files directly
onto the server, the application can upload them into the S3 bucket. The database stores the file information so the user
can identify which file belongs to which storage key.

The application uses STORAGE_DRIVER setting in config.js to decide which storage method to use. This can be set to either local
or s3, allowing the application to switch between the two storage methods without changing the main file management code.

When a user wants to access or download a file, the backend generates a temporary signed URL. When using local storage, this
link points to the storage route the application uses. When using S3 the backend generates a temporary URL that points directly
to the S3 file. Both types of signed URLs expire after one hour.

This allows the frontend to access the files without needing to know exactly where they are stored

---

## 7 Authentication and Security

The dropbox application uses JSON Web Tokens to manage user authentication and protect user accounts. Once a user logs in, or
registers an account the server generates JWT token in the backend and sends it to the frontend. This allows the user to stay logged
into their account without constantly needing to log back in. These tokens expire after 7 days.

When applicationuses bcrypt to securely hash passwords before storing them in the MYSQL database. When a user logs inbcrypt compares
the entered password with the stored password to check whether they match and the details are correct.

The backend uses authentication middleware to protect routes that require a logged-in user. The auth.middleware.js file checks the token
sent with each request and identifies which user is making the request.

Several security features are implemented. These include Helmet which adds security related HTTP headers, while CORS controls which
frontend origin can access the API through a browser. ZOD is used to validate information sent to the backend, and Multer limits uploaded
files to 50 MB by default

The application uses signed URLs to provide temporary access to stored files. The APP_SECRET variable is used to sign authetnication tokens
and local storage links.

---

## 8 AWS Infrastructure and Deployment

The dropbox application uses AWS to host and deploy the application. Several AWS services are used to manage the infrastructure and support
the application.

Amazon EC2 ensures the application can run using Docker containers. Amazon ECR is used to store the Docker images that get uploaded in
Dropbox.

Amazon S3 is used as cloud storage for uploaded files when the application is configured to use S3 storage. The difference between S3 and MYSQL,
is the S3 stores the actual file, whereas MYSQL stores the information for that file. Cloudfront is configured to act as an entry point for users accessing the application, by
forwarding requests to the EC2 origin.

AWS IAM manages permissions for accessing the AWS services, including different roles and users. The EC2 instance uses an IAM role to access the different
services used when developing the application, such as ECR AND S3.

The application uses Docker to package the backend and frontend into a production image. This makes sure its easier to run the application.

Deployment is automated using Github Actions. When code is pushed to the main branch, the workflow builds the production Docker image and uploads it to
Amazon ECR. Github Actions then uses AWS Systems Manager to send a deployment command to the EC2 instance.

The deployment script downloads the new image and runs any required database migrations and starts the new application container.

---

## 9 CI/CD Pipeline (Github Actions)

The project uses Github Actions to automate code checking, building and deployment. This is known as Continuous Integration and Continuous Deployment.

The project contains two workflows on Github Actions, which include checks.yml, publish.yml. The publish.yml contains two jobs which are publish and
deploy.

The checks.yml workflow is responsible for checking the application. It runs when code is pushed to the main branch or when a pull request is made.
It contains seperate jobs for Docker, the backend and the frontend. The three jobs check the Docker image, backend and frontend. These checks
can identify issues with the application before it is deployed.

The publish .yml workflow is responsible for building and deploying the application. It runs when code is pushed to the main branch. The publish job
connects Github Actions to AWS using OpenID Connect (OIDC). It logs into the ECR in AWS and builds the production image and the image is then tagged
using both latest and the Git commit SHA before being uploaded to ECR.

After the image has been successfully uploaded, the deploy job uses AWS Systems Manager to send a deployment command to the EC2 instance. This runs
the deployment script, which downloads the new image. It performs the required database migrations and starts the updated application container.

The Github Actions workflow runs both the publish and deploy jobs and if successful after pushing to the main branch, both jobs are executed. This
shows the application can upload to the ECR and be deployed on the EC2 instance.

Overall, Github Actions automates the process of checking, building and deploying the application, reducing the need for manual deployment and
helping maintain a reliable application.

---

## 10 Testing and Error Handling

The project uses automated testing and error handling to help ensure the application works correctly and responds correctly when errors occur.

The backend uses Vitest as its testing framework. Vitest allows automated tests to be written and executed to check that parts of the backend
behave as expected. The Github Actions workflow runs the backend tests whenever code is pushed to main or a pull request is created. It also
runs separate Docker and frontend jobs.

The Github actions workflow also performs additional jobs, including linting, formatting checks and building the frontend and Docker images.
These checks ensure any errors can be addressed before the application is deployed.

The backend also includes a health check endpoint at /health. This endpoint performs a simple database query to check that the backend can
communicate with MYSQL. The deployment script uses a health check after starting a new application container to check that the appplication is
running correctly. If deployment fails, it attempts to restore a previous version.

Error handling is managed through middleware. The unknownendpoint middleware handles requests to API routes that do not exist by returning a 404
response. The errorhandler middleware handles errors and returns appropriate responses instead of exposing unnecessary internal information.

The project uses Zod validation middleware to check incoming request data. This helps prevent invalid data from being processed. File upload
errors are also handled, with files exceeding the configured upload limit returning a 413 Payload Too Large response.

The frontend has its own error handling in client.js. If the backend returns a 4011 Unauthorized response, the frontend clears the stored
authentication token and redirects the users to the login page.

Overall, testing and error handling help make the application more reliable by identifying problems early and ensuring that errors are handled
appropriately.
