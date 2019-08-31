namespace LargeFileExchange.Exception
{
    public class NotFoundException : ApiException
    {
        public NotFoundException(string msg) : base(404, msg)
        {
        }
    }
}