using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;
using Swashbuckle.AspNetCore.Swagger;
using Swashbuckle.AspNetCore.SwaggerGen;
using System.Net;
using System.IO;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Cors;
using LargeFileExchange.Service;
using LargeFileExchange.Data;
using LargeFileExchange.Model;
using Microsoft.Extensions.Configuration;

namespace LargeFileExchange.Controllers
{



    /// <summary>
    /// File Management Controller
    /// </summary>
    /// <remarks>Manages upload sessions</remarks>
    [Route("api/file")]
    [EnableCors("MyPolicy")]
    public class FileController : Controller
    {
        private IConfiguration _config;

        private UploadService _uploadService;

        public FileController(IConfiguration config)
        {
            _config = config;
            _uploadService = new UploadService(new BlobFileSystemRepository(_config));
        }

        /// <summary>
        /// Create an upload session
        /// </summary>
        /// <remarks>creates a new upload session</remarks>
        /// <param name="userId">User ID</param>
        /// <param name="sessionParams">Session creation params</param>
        [HttpPost("create/{userId}")]
        [Produces("application/json")]
        [SwaggerResponse(201, Type = typeof(SessionCreationStatusResponse))]
        [SwaggerResponse(500)]
        public SessionCreationStatusResponse StartSession([FromRoute] long userId,
                         [FromForm] CreateSessionParams sessionParams)
        {

            Session session = _uploadService.createSession(userId, sessionParams.FileName,
                                                          sessionParams.ChunkSize.Value,
                                                          sessionParams.TotalSize.Value);

            return SessionCreationStatusResponse.fromSession(session);
        }

        /// <summary>
        /// Uploads a file chunk
        /// </summary>
        /// <remarks>uploads a file chunk</remarks>
        /// <param name="userId">User ID</param>
        /// <param name="sessionId">Session ID</param>
        /// <param name="chunkNumber">Chunk number (starts from 1)</param>
        /// <param name="inputFile">File chunk content</param>
        [HttpPut("upload/user/{userId}/session/{sessionId}/")]
        [Produces("application/json")]
        [Consumes("multipart/form-data")]
        [SwaggerResponse(200, Description = "Block upload successfully")]
        [SwaggerResponse(202, Description = "Server busy during that particular upload. Try again")]
        [SwaggerResponse(410, Description = "Session timeout")]
        [SwaggerResponse(500, Description = "Internal server error")]
        public JsonResult UploadFileChunk([FromRoute, Required] long? userId,
                                        [FromRoute, Required] string sessionId,
                                        [FromQuery, Required] int? chunkNumber,
                                        [FromForm] IFormFile inputFile)
        {
            if (!userId.HasValue)
                return badRequest("User missing");

            if (String.IsNullOrWhiteSpace(sessionId))
                return badRequest("Session ID is missing");

            if (chunkNumber < 1)
                return badRequest("Invalid chunk number");

            // due to a bug, inputFile comes null from Mvc
            // however, I want to test the code and have to pass it to the UploadFileChunk function...
            IFormFile file = (inputFile ?? Request.Form.Files.First());

            _uploadService.persistBlock(sessionId, userId.Value, chunkNumber.Value, ToByteArray(file.OpenReadStream()));

            return Json("Ok");
        }

        /// <summary>
        /// Gets the status of a single upload
        /// </summary>
        /// <remarks>gets the status of a single upload</remarks>
        /// <param name="sessionId">Session ID</param>
        [HttpGet("upload/{sessionId}")]
        [Produces("application/json")]
        [SwaggerResponse(404, Description = "Session not found")]
        [SwaggerResponse(500, Description = "Internal server error")]
        [SwaggerResponse(200, typeof(UploadStatusResponse))]
        public UploadStatusResponse GetUploadStatus([FromRoute, Required] string sessionId)
        {
            return UploadStatusResponse.fromSession(_uploadService.getSession(sessionId));
        }

        /// <summary>
        /// Gets the status of all uploads
        /// </summary>
        /// <remarks>gets the status of all uploads</remarks>
        [HttpGet("uploads")]
        [Produces("application/json")]
        [SwaggerResponse(404, Description = "Session not found")]
        [SwaggerResponse(200, typeof(List<UploadStatusResponse>))]
        public List<UploadStatusResponse> GetAllUploadStatus()
        {
            return UploadStatusResponse.fromSessionList(_uploadService.getAllSessions());
        }

        /// <summary>
        /// Downloads a previously uploaded file
        /// </summary>
        /// <param name="sessionId">Session ID</param>
        /// <remarks>downloads a previously uploaded file</remarks>
        [HttpGet("download/{sessionId}")]
        [Produces("multipart/form-data")]
        [SwaggerResponse(200, Description = "OK")]
        [SwaggerResponse(404, Description = "Session not found")]
        [SwaggerResponse(500, Description = "Internal server error")]
        public void DownloadFile([FromRoute, Required] string sessionId)
        {
            Session session = _uploadService.getSession(sessionId);

            var response = targetResponse ?? Response;

            response.ContentType = "application/octet-stream";
            response.ContentLength = session.FileInfo.FileSize;
            response.Headers["Content-Disposition"] = "attachment; fileName=" + session.FileInfo.FileName;

            _uploadService.WriteToStream(targetOutputStream ?? Response.Body, session);
        }

        private byte[] ToByteArray(Stream stream)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                stream.CopyTo(ms);
                return ms.ToArray();
            }
        }

        private JsonResult badRequest(string message)
        {
            var result = new JsonResult("{'message': '" + message + "' }");
            result.StatusCode = 400;
            return result;
        }

        Stream targetOutputStream = null;
        // intended for integration tests only
        [ApiExplorerSettings(IgnoreApi = true)]
        public void SetOuputStream(Stream replacementStream)
        {
            this.targetOutputStream = replacementStream;
        }

        HttpResponse targetResponse = null;
        [ApiExplorerSettings(IgnoreApi = true)]
        public void SetTargetResponse(HttpResponse replacementResponse)
        {
            this.targetResponse = replacementResponse;
        }
    }
}
