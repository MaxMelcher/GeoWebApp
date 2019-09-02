using System;
using System.IO;
using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Blob;
using Microsoft.Extensions.Configuration;

namespace LargeFileExchange.Data
{
    public class BlobFileSystemRepository : FileRepository
    {
        private IConfiguration _config;
        private CloudBlobClient _blobClient;
        private CloudBlobContainer _container;

        public BlobFileSystemRepository(IConfiguration config)
        {
            _config = config;
            string storageConnectionString = _config["storage"];
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);
            _blobClient = storageAccount.CreateCloudBlobClient();

            string containerName = "files";
            _container = _blobClient.GetContainerReference(containerName);

            try
            {
                _container.CreateIfNotExists();
            }
            catch
            {
                Console.WriteLine("Please make sure you have put the correct storage connection string in the environment variable 'storageconnectionstring'.");
                Console.ReadLine();
                throw;
            }
        }

        public async override void Persist(string id, int chunkNumber, byte[] buffer)
        {
            CloudBlockBlob blockBlob = null;

            // Upload a BlockBlob to the newly created container.
            var path = Path.Combine(id, chunkNumber.ToString());
            blockBlob = _container.GetBlockBlobReference(path);

            BlobRequestOptions options = new BlobRequestOptions()
            {
                LocationMode = Microsoft.Azure.Storage.RetryPolicies.LocationMode.PrimaryThenSecondary
            };

            await blockBlob.UploadFromByteArrayAsync(buffer, 0, buffer.Length, null, options, null);
        }

        public override byte[] Read(string id, int chunkNumber)
        {
            //todo: intermediate commit
            //blockBlob.DownloadToFileAsync(string.Format("./CopyOf{0}", ImageToUpload), FileMode.Create, null, null, operationContext);
            throw new NotImplementedException();
        }

    }
}